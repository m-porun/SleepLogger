# ヘルスケアデータインポート用のフォームオブジェクトさん
# Gemfileから使いたいライブラリを呼び出す
require 'zip' # zipファイル解凍用
require 'nokogiri' # パース用

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

  # ファイルは選択されているか？
  validates :zip_file, presence: true
  # ZIPファイル形式のバリデーション集
  validate :validate_zip_file

  # SleepAnalusisシリーズの中から、AsleepOnspecifiedだけ除外する用の定数
  # さらに、freezeで定数をこれ以上変更できないようにする
  EXCLUDE_FROM_EXTRACT = %w[HKCategoryValueSleepAnalysisAsleepUnspecified].freeze

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
  end

  def process_file
    pp 'process_fileです'
    # zipファイルかどうかのバリデーションチェック
    return false unless valid?

    # zipからXML内容を抽出するメソッドの呼び出し
    begin
      if extract_xml_content
        # 抽出したxmlファイルの文字列をNokogiriでオブジェクト化->構文解析する
        parsed_content = Nokogiri::XML(@xml_content)
        # フィルター用メソッド呼び出し
        @filtered_sleep_records = extract_and_filter_records(parsed_content)
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

  # レコードのフィルタリングメソッド
  def extract_and_filter_records(parsed_content)
    # xmlオブジェクトの中から、階層問わず@typeに当てはまるレコードをまるっと抽出
    parsed_content.xpath('//Record[@type="HKCategoryTypeIdentifierSleepAnalysis"]').select do |record|
      # 定数HKCategoryValueSleepAnalysisAsleepUnspecifiedを除外
      !EXCLUDE_FROM_EXTRACT.include?(record['value'])
    end
  end
end
