# ヘルスケアデータインポート用のフォームオブジェクトさん
# Gemfileから使いたいライブラリを呼び出す
require 'zip' # zipファイル解凍用
require 'nokogiri' # パース用

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
    return unless name == 'Record'

    # Recordの中にはstartDate="2025-07-17 02:08:43 +0900"などが空白区切りで入っている
    # SAXパーサがそれらを読み込んでattrsに[["type", "HKQuantityTypeIdentifierPhysicalEffort"],["key", "value"],...]を渡す
    # その配列をさらにハッシュへ変換
    attrs_hash = Hash[attrs]

    # typeの値が睡眠タイプHKCategoryTypeIdentifierSleepAnalysis出ない場合は除外
    return unless attrs_hash['type'] == 'HKCategoryTypeIdentifierSleepAnalysis'

    # 仕分け用の前準備(InBed対策、62日分のレコード対策)
    record_value = attrs_hash['value']
    record_start_date = Time.parse(attrs_hash['startDate']) rescue nil # ないならnil

    # フィルタリング発動
    if record_start_date.present? &&
       record_start_date >= @cutoff_date &&
       !EXCLUDE_FROM_EXTRACT.include?(record_value)

      # フィルターを通過したレコードを保持(InBed含む全てのレコード)
      @filtered_sleep_records << attrs_hash

      # InBed(ベッドに入った時間)があるかないかで仕分け
      if record_value == 'HKCategoryValueSleepAnalysisInBed'
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

  # ファイルは選択されているか？
  validates :zip_file, presence: true
  # ZIPファイル形式のバリデーション集
  validate :validate_zip_file

  # 引数には、キー名がzip_fileとuserのハッシュが渡されてくる
  def initialize(attributes = {}) # もし引数にattributesが渡されなかったら、空のハッシュを入れる
    pp 'importフォームのinitializeメソッドです'
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
  end

  def process_file
    pp 'process_fileです'
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

        # Asleepレコードを日別でグループ化
        group_sleep_records
        
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
    unless zip_file.content_type == 'application/zip'
      errors.add(:zip_file, 'ZIPファイルを選択してください')
    end
  end

  # XML抽出メソッド
  def extract_xml_content
    # Tempfileライブラリを利用して、一時ファイルに保存されたTemplateオブジェクトのフルパスを返す
    Zip::File.open(zip_file.tempfile.path) do |zip_file_obj|
      # 頑張ってexport.xmlファイルを探し出せ！
      export_entry = zip_file_obj.glob('**/apple_health_export/export.xml').first
      # それでも見つからなかったら、ルート直下で探せ！
      unless export_entry
        export_entry = zip_file_obj.find_entry('export.xml').first
        unless export_entry
          # 属性には基づかないファイル全体のエラーに:base
          errors.add(:base, 'export.xmlファイルが見つからないです')
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
      record_start = Time.parse(record['startDate']) rescue nil
      record_end = Time.parse(record['endDate']) rescue nil

      next unless record_start && record_end # 時刻を読み取れなければスキップ

      if current_block.nil? # 最初のブロック
        current_block = {
          start_date: record_start,
          end_date: record_end,
          duration_minutes: (record_end - record_start) / 60 # 小数点の扱いが難しいので分変換で計算
        }
      elsif record_start == current_block[:end_date] # 前のレコードendと今回のレコードstartが連続している場合
        # 今回のレコードendを現在のブロックendに代入
        current_block[:end_date] = record_end
        # 今回のレコード始まりから終わりまでの時間を累計時間に足す
        current_block[:duration_minutes] += (record_end - record_start) / 60
      else # 連続が途切れた場合、現在のブロックを保存して新しいブロックを開始
        @sleep_blocks << current_block
        current_block = {
          start_date: record_start,
          end_date: record_end,
          duration_minutes: (record_end - record_start) / 60
        }
      end
    end
    # 連続が途切れたら、ひとかたまり分の睡眠データを配列に入れる
    @sleep_blocks << current_block if current_block
  end
end
