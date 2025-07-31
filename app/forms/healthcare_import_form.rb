# ヘルスケアデータインポート用のフォームオブジェクトさん
# Gemfileから使いたいライブラリを呼び出す
require "zip" # zipファイル解凍用
require "nokogiri" # パース用

# XMLをSAX方式で解析するためのハンドラクラス。イベントに対してどう処理するか
# 解析処理を軽くするため、XMLの要素から必要なデータだけを抽出する
class HealthcareImportSaxHandler < Nokogiri::XML::SAX::Document
  # attr_reader :filtered_sleep_records, :in_bed_records, :asleep_records

  # SleepAnalusisシリーズの中から、AsleepOnspecifiedだけ除外する用の定数
  # さらに、freezeで定数をこれ以上変更できないようにする
  EXCLUDE_FROM_EXTRACT = %w[HKCategoryValueSleepAnalysisAsleepUnspecified].freeze

  # 4つの睡眠パターンを丸っと管理する定数。ただしAwake(中途覚醒)は除く
  ASLEEP_VALUES = %w[
    HKCategoryValueSleepAnalysisAsleep
    HKCategoryValueSleepAnalysisAsleepCore
    HKCategoryValueSleepAnalysisAsleepDeep
    HKCategoryValueSleepAnalysisAsleepREM
    HKCategoryValueSleepAnalysisAwake
  ].freeze

  # 取り扱う日数の定数
  DAYS_TO_KEEP = 31

  # 日付の変わり目を決める定数(午前4時)
  DAILY_CUT_OFF_HOUR= 4

  # 必要なデータを抽出して入れておく配列たち
  # SAXハンドラー内で一時的に日別集計を保持
  def initialize(record_processor:, daily_summaries:)
    pp "initialize"
    @record_processor = record_processor # 日別集計が確定した際に呼び出すコールバック
    @daily_summaries = daily_summaries # フォームオブジェクトに共有する日別集計ハッシュ
    @cutoff_date = (Time.current - DAYS_TO_KEEP.days).beginning_of_day
    @last_processed_date = nil # 最後に処理した睡眠日を追跡する
  end

  # XML要素の中で、開始タグを見つけたら以下を発動
  def start_element(name, attrs = [])
    # タグの冒頭がRecordで始まらないものは除外
    return unless name == "Record"

    # 調べたいキー用に、変数を初期化。Hash化して調べるよりかは早い？
    type_val = nil
    start_date_str = nil
    end_date_str = nil
    value_str = nil

    # 調べたいキーの値を変数に放り込んでいく
    attrs.each do |attr_name, attr_value|
      case attr_name
      when "type"
        type_val = attr_value
      when "startDate"
        start_date_str = attr_value
      when "endDate"
        end_date_str = attr_value
      when "value"
        value_str = attr_value
      end
      # 必要なものが全て見つかったらループを抜ける (早期終了)
      break if type_val && start_date_str && end_date_str && value_str
    end

    # typeの値が睡眠タイプHKCategoryTypeIdentifierSleepAnalysis出ない場合は除外
    return unless type_val == "HKCategoryTypeIdentifierSleepAnalysis"

    # Recordの中にはstartDate="2025-07-17 02:08:43 +0900"などが空白区切りで入っている
    # perseよりも高速なstrptimeを使用
    record_start_time = Time.strptime(start_date_str, "%Y-%m-%d %H:%M:%S %z") rescue nil
    record_end_time = Time.strptime(end_date_str, "%Y-%m-%d %H:%M:%S %z") rescue nil

    # 時刻が取得できないか、期間対象外か、除外対象の値の場合はスキップ
    if record_start_time.nil? || record_end_time.nil? ||
       record_start_time < @cutoff_date ||
       EXCLUDE_FROM_EXTRACT.include?(value_str)
      return
    end

    # 睡眠日を決める
    current_sleep_date = calculate_sleep_date(record_end_time)

    # 新しい日付に更新されたら、それまでメモリに覚えさせていた日別のサマリーを処理する
    if @last_processed_date && @last_processed_date != current_sleep_date
      # 完全に集計が終わった日付のデータをプロセッサに渡す
      if @daily_summaries[@last_processed_date] && @record_processor
        @record_processor.call(@last_processed_date, @daily_summaries.delete(@last_processed_date))
      end
    end

    @last_processed_date = current_sleep_date # 現在処理中の日付を更新

    # 現在の睡眠日のサマリーを初期化（存在しない場合）
    @daily_summaries[current_sleep_date] ||= {
      in_bed_records: [],
      asleep_records: [],
      sleep_blocks: [] # ここで sleep_blocks はまだ生成されない
    }

    # 必要な属性のみを含むハッシュを作成して追加 (メモリ削減)
    record_data = {
      "type" => type_val,
      "startDate" => start_date_str,
      "endDate" => end_date_str,
      "value" => value_str
    }

    # InBed(ベッドに入った時間)があるかないかで仕分け
    if value_str == "HKCategoryValueSleepAnalysisInBed"
      @daily_summaries[current_sleep_date][:in_bed_records] << record_data
    elsif ASLEEP_VALUES.include?(value_str)
      @daily_summaries[current_sleep_date][:asleep_records] << record_data
    end
  end

  # ドキュメントの終わりに到達したら、最後に残っている集計データを処理
  # メモリを解放
  def end_document
    if @last_processed_date && @daily_summaries[@last_processed_date] && @record_processor
      @record_processor.call(@last_processed_date, @daily_summaries.delete(@last_processed_date))
    end
  end

  private

  # 睡眠日の決定：今朝起きた日を決める (SAXハンドラー内で使用)
  def calculate_sleep_date(end_time)
    return nil unless end_time.present? && end_time.respond_to?(:hour)

    # 終了時刻が日付切り替え時刻の午前4時より前かどうかで日付を決める
    if end_time.hour < DAILY_CUT_OFF_HOUR
      end_time.prev_day.to_date # 前日にする
    else
      end_time.to_date
    end
  end
end


# こっからフォームオブジェクト！
class HealthcareImportForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # アップロードzipファイル受け取り属性
  attribute :zip_file
  # paramsのときにcurrent_userをマージしている
  attr_accessor :user
  # 解凍したXMLファイルを扱う
  attr_accessor :xml_content
  # インポートした数
  attr_accessor :imported_count

  # ファイルは選択されているか？
  validates :zip_file, presence: true
  # ZIPファイル形式のバリデーション集
  validate :validate_zip_file

  # 引数には、キー名がzip_fileとuserのハッシュが渡されてくる
  def initialize(attributes = {}) # もし引数にattributesが渡されなかったら、空のハッシュを入れる
    pp "ImportForm initialize"
    # zip_fileのみを加工できるように、Userモデルのインスタンスを切り出してインスタンス変数に入れておく
    @user = attributes.delete(:user)
    # zip_fileをattributesに渡す
    super(attributes)
    # 空っぽを作るシリーズ
    @xml_content = nil
    @imported_count = 0
  end

  def process_file
    return false unless valid?

    xml_extract_success = false
    xml_extract_success = extract_xml_content

    if xml_extract_success
      # 日ごとのサマリーをSAXハンドラーと共有するためのハッシュ
      # SAXハンドラーはこのハッシュにデータを蓄積し、日付が変わるとdaily_summary_processorに渡す
      daily_summaries_in_progress = {}

      # SAXハンドラーから日別データが確定した際に呼び出されるコールバック
      daily_summary_processor = Proc.new do |sleep_date, summary_data|
        # ここで、SAXハンドラーから渡された日別データを元に、SleepLogを保存する
        process_daily_sleep_data(sleep_date, summary_data)
      end

      # SAXハンドラーのインスタンス化とパース
      sax_handler = HealthcareImportSaxHandler.new(
        record_processor: daily_summary_processor,
        daily_summaries: daily_summaries_in_progress
      )
      Nokogiri::XML::SAX::Parser.new(sax_handler).parse(@xml_content)

      true
    else
      false
    end
  rescue => e
    Rails.logger.error "ファイル処理中にエラーが発生しました: #{e.message}\n#{e.backtrace.join("\n")}"
    errors.add(:base, "ファイル処理中にエラーが発生しました: #{e.message}")
    false
  end

  private

  # ZIPファイルのみを受け付けるバリデーション
  def validate_zip_file
    return unless zip_file.present?

    unless zip_file.content_type == "application/zip"
      errors.add(:zip_file, "ZIPファイルを選択してください")
    end
  end

  # XML抽出メソッド
  def extract_xml_content
    pp "extract_xml_content"
    Zip::File.open(zip_file.tempfile.path) do |zip_file_obj|
      export_entry = zip_file_obj.glob("**/apple_health_export/export.xml").first
      unless export_entry
        export_entry = zip_file_obj.find_entry("export.xml")
        unless export_entry
          errors.add(:base, "export.xmlファイルが見つからないです")
          return false
        end
      end

      @xml_content = export_entry.get_input_stream.read
      true
    end
  end

  # 日別データを受け取り、睡眠ブロックのグループ化とデータベース保存を実行する
  def process_daily_sleep_data(sleep_date, summary_data)
    pp "process_daily_sleep_data"
    in_bed_records = summary_data[:in_bed_records]
    asleep_records_raw = summary_data[:asleep_records] # 生のAsleepレコード

    # ここで生データから睡眠ブロックをグループ化するロジックを再構築
    sleep_blocks_for_the_day = group_asleep_records_into_blocks(asleep_records_raw)

    if in_bed_records.any?
      process_with_in_bed_data(sleep_date, sleep_blocks_for_the_day, in_bed_records)
    else
      process_without_in_bed_data(sleep_date, sleep_blocks_for_the_day)
    end
    @imported_count += 1 # 1日分のデータが保存されるたびにカウント
  end

  # Asleepレコードの生データから睡眠ブロックを生成する新しいヘルパーメソッド
  def group_asleep_records_into_blocks(asleep_records_raw)
    return [] if asleep_records_raw.empty?

    current_block = nil
    blocks = []

    # 時刻順にソートする (XMLの順序が保証されない場合のため)
    sorted_asleep_records = asleep_records_raw.sort_by do |record|
      Time.strptime(record["startDate"], "%Y-%m-%d %H:%M:%S %z") rescue Time.at(0)
    end

    sorted_asleep_records.each do |record|
      record_start = Time.strptime(record["startDate"], "%Y-%m-%d %H:%M:%S %z") rescue nil
      record_end = Time.strptime(record["endDate"], "%Y-%m-%d %H:%M:%S %z") rescue nil

      next unless record_start && record_end # 時刻を読み取れなければスキップ

      if current_block.nil? # 最初のブロック
        current_block = {
          start_date: record_start,
          end_date: record_end,
          duration_minutes: (record_end - record_start) / 60,
          records: [ record ]
        }
      elsif record_start == current_block[:end_date] # 前のレコードendと今回のレコードstartが連続している場合
        current_block[:end_date] = record_end
        current_block[:duration_minutes] += (record_end - record_start) / 60
        current_block[:records] << record
      else # 連続が途切れた場合、現在のブロックを保存して新しいブロックを開始
        blocks << current_block
        current_block = {
          start_date: record_start,
          end_date: record_end,
          duration_minutes: (record_end - record_start) / 60,
          records: [ record ]
        }
      end
    end
    # 最後のブロックを追加
    blocks << current_block if current_block
    blocks
  end

  # InBedレコードがある場合の睡眠記録加工
  def process_with_in_bed_data(sleep_date, asleep_block_details, in_bed_record_details)
    main_in_bed_record = in_bed_record_details.first # 例えInBedレコードが2つあっても1つとして扱います！
    go_to_bed_at = Time.strptime(main_in_bed_record["startDate"], "%Y-%m-%d %H:%M:%S %z") rescue nil
    leave_bed_at = Time.strptime(main_in_bed_record["endDate"], "%Y-%m-%d %H:%M:%S %z") rescue nil

    main_sleep_chunks = [] # InBed範囲内の睡眠ブロック
    nap_chunks = [] # InBed範囲外の睡眠ブロック=昼寝時間

    # 各睡眠レコードが、ベッドに入った時間内なら睡眠時間として、そうでないなら昼寝時間として扱わせる
    asleep_block_details.each do |block|
      block_start = block[:start_date]
      block_end = block[:end_date]

      # go_to_bed_at と leave_bed_at がnilでないことを確認
      if go_to_bed_at && leave_bed_at && block_start >= go_to_bed_at && block_end <= leave_bed_at
        main_sleep_chunks << block
      else
        nap_chunks << block
      end
    end

    fell_asleep_at = main_sleep_chunks.map { |b| b[:start_date] }.min if main_sleep_chunks.any?
    woke_up_at = main_sleep_chunks.map { |b| b[:end_date] }.max if main_sleep_chunks.any?

    # Awakeningモデルの覚醒回数を計算
    awakenings_count = main_sleep_chunks.sum do |block|
      block[:records].count { |r| r["value"] == "HKCategoryValueSleepAnalysisAwake" }
    end

    # Nappingモデルの昼寝時間を計算
    napping_time = calculate_total_duration_minutes(nap_chunks)

    save_sleep_log(
      sleep_date: sleep_date,
      go_to_bed_at: go_to_bed_at,
      fell_asleep_at: fell_asleep_at,
      woke_up_at: woke_up_at,
      leave_bed_at: leave_bed_at,
      awakenings_count: awakenings_count,
      napping_time: napping_time,
      comment: ""
    )
  end

  # InBedレコードがない場合の睡眠記録加工
  def process_without_in_bed_data(sleep_date, asleep_block_details)
    # 最も長い睡眠チャンクを主な睡眠と捉える
    longest_chunk = asleep_block_details.max_by { |block| block[:duration_minutes] }

    # longest_chunk が存在しない場合は処理をスキップ (Asleepレコードが全くない場合など)
    return unless longest_chunk

    other_chunk = asleep_block_details - [ longest_chunk ] # それ以外を昼寝と判定

    # 主要な睡眠の時刻をSleepLogモデル用のカラムにセット
    go_to_bed_at = longest_chunk[:start_date]
    fell_asleep_at = longest_chunk[:start_date] # InBedが存在しないので、go_to_bed_atと同値になる
    woke_up_at = longest_chunk[:end_date]
    leave_bed_at = longest_chunk[:end_date]

    # 中途覚醒のレコードがあった数をカウント
    awakenings_count = longest_chunk[:records].count { |r| r["value"] == "HKCategoryValueSleepAnalysisAwake" }

    # 昼寝時間
    napping_time = calculate_total_duration_minutes(other_chunk)

    save_sleep_log(
      sleep_date: sleep_date,
      go_to_bed_at: go_to_bed_at,
      fell_asleep_at: fell_asleep_at,
      woke_up_at: woke_up_at,
      leave_bed_at: leave_bed_at,
      awakenings_count: awakenings_count,
      napping_time: napping_time,
      comment: ""
    )
  end

  # 一塊の合計時間を求めるだけのメソッド
  def calculate_total_duration_minutes(blocks)
    blocks.sum { |block| block[:duration_minutes].to_i }
  end

  # saveをするメソッド
  def save_sleep_log(attributes)
    pp "save_sleep_log"
    # ユーザーと睡眠日に基づく睡眠記録を探し、なければ新規作成
    sleep_log = @user.sleep_logs.find_or_initialize_by(sleep_date: attributes[:sleep_date])

    # 秒切り捨て
    go_to_bed_at_truncated = attributes[:go_to_bed_at]&.change(sec: 0)
    fell_asleep_at_truncated = attributes[:fell_asleep_at]&.change(sec: 0)
    woke_up_at_truncated = attributes[:woke_up_at]&.change(sec: 0)
    leave_bed_at_truncated = attributes[:leave_bed_at]&.change(sec: 0)

    # 属性をSleepLogインスタンスに設定する&秒切り捨て
    sleep_log.assign_attributes(
      go_to_bed_at: go_to_bed_at_truncated,
      fell_asleep_at: fell_asleep_at_truncated,
      woke_up_at: woke_up_at_truncated,
      leave_bed_at: leave_bed_at_truncated
    )

    # 子モデルの関連付けと属性設定
    # Awakening
    awakening = sleep_log.awakening || sleep_log.build_awakening
    awakening.awakenings_count = attributes[:awakenings_count] || 0

    # NappingTime
    napping_time_record = sleep_log.napping_time || sleep_log.build_napping_time
    napping_time_record.napping_time = attributes[:napping_time] || 0

    # Comment
    comment_record = sleep_log.comment || sleep_log.build_comment
    if comment_record.comment.blank?
      comment_record.comment = attributes[:comment] || ""
    end

    SleepLog.transaction do
      sleep_log.save!
      awakening.save!
      napping_time_record.save!
      comment_record.save!
    end
    # @imported_count += 1 # カウントはprocess_daily_sleep_dataで行う
  end
end
