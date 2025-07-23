# ヘルスケアデータインポート用のフォームオブジェクトさん
class HealthcareImportForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  # アップロードzipファイル受け取り属性
  attribute :zip_file
  # paramsのときにcurrent_userをマージしている
  attr_accessor :user

  validates :zip_file, presence: true

  # 引数には、キー名がzip_fileとuserのハッシュが渡されてくる
  def initialize(attributes = {}) # もし引数にattributesが渡されなかったら、空のハッシュを入れる
    # zip_fileのみを加工できるように、Userモデルのインスタンスを切り出してインスタンス変数に入れておく
    @user = attributes.delete(:user)
    # zip_fileをattributesに渡す
    super(attributes)
  end

  def process_file
    pp 'process_fileです'
    true
  end
end
