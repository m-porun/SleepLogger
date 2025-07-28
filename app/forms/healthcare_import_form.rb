# ヘルスケアデータインポート用のフォームオブジェクトさん
# Gemfileから使いたいライブラリを呼び出す
require "zip" # zipファイル解凍用
require "nokogiri" # パース用

# XMLをSAX方式で解析するためのハンドラクラス。イベントに対してどう処理するか
# 解析処理を軽くするため、XMLの要素から必要なデータだけを抽出する
class HealthcareImportSaxHandler < Nokogiri::XML::SAX::Document
  attr_reader :filtered_sleep_records, :in_bed_records, :asleep_records

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
  DAYS_TO_KEEP = 62

  # 必要なデータを抽出して入れておく配列たち
  def initialize
    @filtered_sleep_records = []
    @in_bed_records = []
    @asleep_records = []
    @cutoff_date = (Time.current - DAYS_TO_KEEP.days).beginning_of_day
  end

  # XML要素の中で、開始タグを見つけたら以下を発動
  def start_element(name, attrs = [])
    # タグの冒頭がRecordで始まらないものは除外
    return unless name == "Record"

    # assocメソッドを使って、type属性のキーバリューペアを返す
    type_pair = attrs.assoc("type")

    # typeの値が睡眠タイプHKCategoryTypeIdentifierSleepAnalysis出ない場合は除外
    return unless type_pair && type_pair[1] == "HKCategoryTypeIdentifierSleepAnalysis"

    # Recordの中にはstartDate="2025-07-17 02:08:43 +0900"などが空白区切りで入っている
    # SAXパーサがそれらを読み込んでattrsに[["type", "HKQuantityTypeIdentifierPhysicalEffort"],["key", "value"],...]を渡す
    # その配列をさらにハッシュへ変換
    attrs_hash = Hash[attrs]

    # 仕分け用の前準備(InBed対策、62日分のレコード対策)
    record_value = attrs_hash["value"]
    record_start_date = Time.parse(attrs_hash["startDate"]) rescue nil # ないならnil

    # フィルタリング発動
    if record_start_date.present? &&
       record_start_date >= @cutoff_date &&
       !EXCLUDE_FROM_EXTRACT.include?(record_value)

      # フィルターを通過したレコードを保持(InBed含む全てのレコード)
      @filtered_sleep_records << attrs_hash

      # InBed(ベッドに入った時間)があるかないかで仕分け
      if record_value == "HKCategoryValueSleepAnalysisInBed"
        @in_bed_records << attrs_hash
      elsif ASLEEP_VALUES.include?(record_value)
        @asleep_records << attrs_hash
      end
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
  # フィルタリングしたレコードを扱う
  attr_accessor :filtered_sleep_records
  # InBed(ベッドに入ってから出るまでの期間)があれば、別途保存して扱う
  attr_accessor :in_bed_records
  # それ以外の睡眠タイプを保存して扱う
  attr_accessor :asleep_records
  # ひとかたまりの睡眠データを扱う
  attr_accessor :sleep_blocks
  # 日別の集計結果を保持する
  attr_accessor :daily_sleep_summaries
  # インポートした数
  attr_accessor :imported_count

  # ファイルは選択されているか？
  validates :zip_file, presence: true
  # ZIPファイル形式のバリデーション集
  validate :validate_zip_file

  # 日付の変わり目を決める定数(午前4時)
  DAILY_CUT_OFF_HOUR= 4

  # 引数には、キー名がzip_fileとuserのハッシュが渡されてくる
  def initialize(attributes = {}) # もし引数にattributesが渡されなかったら、空のハッシュを入れる
    pp "importフォームのinitializeメソッドです"
    # zip_fileのみを加工できるように、Userモデルのインスタンスを切り出してインスタンス変数に入れておく
    @user = attributes.delete(:user)
    # zip_fileをattributesに渡す
    super(attributes)
    # 空っぽを作るシリーズ
    @xml_content = nil
    @filtered_sleep_records = []
    @in_bed_records = []
    @asleep_records = []
    @sleep_blocks = []
    @daily_sleep_summaries = {}
    @imported_count = 0
  end

  def process_file
    pp "process_fileです"
    # zipファイルかどうかのバリデーションチェック
    return false unless valid?

    # zipからXML内容を抽出するメソッドの呼び出し
    # 抽出したxmlファイルの文字列をNokogiriでオブジェクト化->構文解析する
    # DOM形式ではなく、SAXパーサーで一行ずつ読み込む
    begin
      if extract_xml_content
        # SAXハンドラーの処理を記した自作クラスのインスタンスを作成
        sax_handler = HealthcareImportSaxHandler.new
        # 構文解析本体のインスタンスを生成
        parser_content = Nokogiri::XML::SAX::Parser.new(sax_handler)
        # XML文字列をSAXパーサーで解析
        parser_content.parse(@xml_content)

        # フィルタリング完了したものをインスタンス変数に格納
        @filtered_sleep_records = sax_handler.filtered_sleep_records
        @in_bed_records = sax_handler.in_bed_records
        @asleep_records = sax_handler.asleep_records

        # InBedレコードにsleep_dateというキーを作成、ベットから出た日付を追加
        @in_bed_records.each do |record|
          record_end_time = Time.parse(record["endDate"]) rescue nil
          record["sleep_date"] = calculate_sleep_date(record_end_time) if record_end_time
        end

        # Asleepレコードを日別でグループ化
        group_sleep_records

        # 日別集計
        summarize_daily_sleep_data

        # 各睡眠日ごとに睡眠データを処理し保存させる
        @daily_sleep_summaries.each do |sleep_date, summary_data|
          process_daily_sleep_data(sleep_date, summary_data)
        end

        true
      else
        false
      end
    rescue => e
      Rails.logger.error "ファイル処理中にエラーが発生しました: #{e.message}\n#{e.backtrace.join("\n")}"
      errors.add(:base, "ファイル処理中にエラーが発生しました: #{e.message}")
      false
    end
  end

  private

  # ZIPファイルのみを受け付けるバリデーション
  def validate_zip_file
    return unless zip_file.present?

    # インポートしたデータのMIMEタイプが'application/zip'かどうかチェック
    unless zip_file.content_type == "application/zip"
      errors.add(:zip_file, "ZIPファイルを選択してください")
    end
  end

  # XML抽出メソッド
  def extract_xml_content
    # Tempfileライブラリを利用して、一時ファイルに保存されたTemplateオブジェクトのフルパスを返す
    Zip::File.open(zip_file.tempfile.path) do |zip_file_obj|
      # 頑張ってexport.xmlファイルを探し出せ！
      export_entry = zip_file_obj.glob("**/apple_health_export/export.xml").first
      # それでも見つからなかったら、ルート直下で探せ！
      unless export_entry
        export_entry = zip_file_obj.find_entry("export.xml")
        unless export_entry
          # 属性には基づかないファイル全体のエラーに:base
          errors.add(:base, "export.xmlファイルが見つからないです")
          return false
        end
      end

      # zipファイルを読み取って、xmlのデータとしてインスタンス変数に代入
      @xml_content = export_entry.get_input_stream.read
      true
    end
  end

  # Asleepレコードを日別でグループ化
  def group_sleep_records
    return if @asleep_records.empty?

    current_block = nil

    @asleep_records.each do |record|
      # ヘルスケアのレコードにおいて、1回睡眠に含まれる複数のレコードはそれぞれ前のendDateと次のstartDateが合致する特徴がある
      # 時刻だけを抽出して、比較する
      record_start = Time.parse(record["startDate"]) rescue nil
      record_end = Time.parse(record["endDate"]) rescue nil

      next unless record_start && record_end # 時刻を読み取れなければスキップ

      if current_block.nil? # 最初のブロック
        current_block = {
          start_date: record_start,
          end_date: record_end,
          duration_minutes: (record_end - record_start) / 60, # 小数点の扱いが難しいので分変換で計算
          records: [ record ] # その日の睡眠レコードたちを丸ごと管理
        }
      elsif record_start == current_block[:end_date] # 前のレコードendと今回のレコードstartが連続している場合
        # 今回のレコードendを現在のブロックendに代入
        current_block[:end_date] = record_end
        # 今回のレコード始まりから終わりまでの時間を累計時間に足す
        current_block[:duration_minutes] += (record_end - record_start) / 60
        # その日分としてまとめる
        current_block[:records] << record
      else # 連続が途切れた場合、現在のブロックを保存して新しいブロックを開始
        # 睡眠日を決定
        current_block[:sleep_date] = calculate_sleep_date(current_block[:end_date])
        @sleep_blocks << current_block
        current_block = {
          start_date: record_start,
          end_date: record_end,
          duration_minutes: (record_end - record_start) / 60,
          records: [ record ]
        }
      end
    end
    # 連続が途切れたら、ひとかたまり分の睡眠データを配列に入れる
    if current_block
      current_block[:sleep_date] = calculate_sleep_date(current_block[:end_date])
      @sleep_blocks << current_block
    end
  end

  # 睡眠日の決定：今朝起きた日を決める
  def calculate_sleep_date(end_time)
    return nil unless end_time.present? && end_time.respond_to?(:hour)

    # 終了時刻が日付切り替え時刻の午前4時より前かどうかで日付を決める
    if end_time.hour < DAILY_CUT_OFF_HOUR
      end_time.prev_day.to_date # 前日にする
    else
      end_time.to_date
    end
  end

  # 日別集計
  def summarize_daily_sleep_data
    @daily_sleep_summaries = {}

    # 一塊の睡眠ブロックから集計していく
    @sleep_blocks.each do |block|
      sleep_date = block[:sleep_date]

      # 合計睡眠時間とそのレコード
      @daily_sleep_summaries[sleep_date] ||= {
        sleep_duration_minutes: 0,
        in_bed_duration_minutes: 0,
        asleep_block_details: [],
        in_bed_record_details: []
      }
      # 一塊の睡眠をそれぞれ合計していく
      @daily_sleep_summaries[sleep_date][:sleep_duration_minutes] += block[:duration_minutes].to_i
      # 詳細なブロック情報
      @daily_sleep_summaries[sleep_date][:asleep_block_details] << block
    end

    # InBedレコードの集計
    @in_bed_records.each do |record|
      sleep_date = record["sleep_date"]

      record_start = Time.parse(record["startDate"]) rescue nil
      record_end = Time.parse(record["endDate"]) rescue nil

      if record_start && record_end
        @daily_sleep_summaries[sleep_date][:in_bed_duration_minutes] += ((record_end - record_start) / 60).to_i
      end

      # InBedレコードの詳細も入れとく
      @daily_sleep_summaries[sleep_date][:in_bed_record_details] << record
    end
  end

  # InBedレコードが存在するか否かで分岐する
  def process_daily_sleep_data(sleep_date, summary_data)
    if summary_data[:in_bed_record_details].any?
      process_with_in_bed_data(sleep_date, summary_data[:asleep_block_details], summary_data[:in_bed_record_details])
    else
      process_without_in_bed_data(sleep_date, summary_data[:asleep_block_details])
    end
  end

  # InBedレコードがある場合の睡眠記録加工
  def process_with_in_bed_data(sleep_date, asleep_block_details, in_bed_record_details)
    # 例えInBedレコードが2つあっても1つとして扱います！
    main_in_bed_record = in_bed_record_details.first
    # SleepLogモデルのベットに入った時刻カラムに入れる準備
    go_to_bed_at = Time.parse(main_in_bed_record["startDate"]) rescue nil
    # SleepLogモデルのベットから出た時刻カラムに入れる準備
    leave_bed_at = Time.parse(main_in_bed_record["endDate"]) rescue nil

    main_sleep_chunks = [] # InBed範囲内の睡眠ブロック
    nap_chunks = [] # InBed範囲外の睡眠ブロック=昼寝時間

    # 各睡眠レコードが、ベッドに入った時間内なら睡眠時間として、そうでないなら昼寝時間として扱わせる
    asleep_block_details.each do |block|
      block_start = block[:start_date]
      block_end = block[:end_date]

      if block_start >= go_to_bed_at && block_end <= leave_bed_at
        main_sleep_chunks << block
      else
        nap_chunks << block
      end
    end

    # SleepLogモデルで眠りについた時刻と目が覚めた時刻を扱う
    # InBed範囲内の一塊の睡眠レコードの内、最初の開始時刻と最後の終了時刻
    fell_asleep_at = main_sleep_chunks.map { |b| b[:start_date] }.min # 順番に並んでない可能性対策
    woke_up_at = main_sleep_chunks.map { |b| b[:end_date] }.max

    # Awakeningモデルの覚醒回数を計算
    awakenings_count = main_sleep_chunks.sum do |block|
      block[:records].count { |r| r["value"] == "HKCategoryValueSleepAnalysisAwake" }
    end

    # Nappingモデルの昼寝時間を計算
    napping_time = calculate_total_duration_minutes(nap_chunks)

    # save用のフォームオブジェクトカラムに各情報を入れていく
    save_sleep_log(
      sleep_date: sleep_date,
      go_to_bed_at: go_to_bed_at,
      fell_asleep_at: fell_asleep_at,
      woke_up_at: woke_up_at,
      leave_bed_at: leave_bed_at,
      awakenings_count: awakenings_count,
      napping_time: napping_time,
      comment: "" # 新規なら空文字、既存の場合は保持
    )
  end

  # InBedレコードがない場合の睡眠記録加工
  def process_without_in_bed_data(sleep_date, asleep_block_details)
    # 最も長い睡眠チャンクを主な睡眠と捉える
    longest_chunk = asleep_block_details.max_by { |block| block[:duration_minutes] }
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
  end
end
