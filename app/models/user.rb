class User < ApplicationRecord
  # ユーザーを削除したら、睡眠記録も一緒に消える
  has_many :sleep_logs, dependent: :destroy
  # SNS認証、今後認証機能付け足す用にhas_many
  has_many :sns_credential, dependent: :destroy

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         # Omniauth用
         :omniauthable, omniauth_providers: %i[google_oauth2]

  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, uniqueness: true

  class << self # メソッソ冒頭につけるself.を省略
    # SnsCredentialsテーブルにデータがない場合
    def without_sns_data(auth)
      user = User.where(email: auth.info.email).first

      if user.present? # 同じメールアドレスが存在する場合、SnsCredentialだけ作る
        sns = SnsCredential.create(
          uid: auth.uid,
          provider: auth.provider,
          user_id: user.id
        )
      else # ユーザー自体存在しない場合、UserとSnsCredential両方作る
        user = User.create(
          name: auth.info.name, # SNSの名前を取得
          email: auth.info.email,
          password: Devise.friendly_token(10) # 即席のランダムパスワード
        )
        sns = SnsCredential.create(
          user_id: user.id,
          uid: auth.uid,
          provider: auth.provider
        )
      end
      { user:, sns: } # ハッシュ形式で呼び出し元にreturn
    end

    # SnsCredentialテーブルにデータがある場合
    def with_sns_data(auth, snscredential)
      user = User.where(id: snscredential.user_id).first
      # Userの中身が空っぽの場合
      if user.blank?
        user = User.create(
          name: auth.info.name, # SNSの名前を取得
          email: auth.info.email,
          password: Devise.friendly_token(10)
        )
      end
      { user: }
    end

    # Googleアカウントの情報をそれぞれの変数に格納して上記のメソッドに振り分ける
    def find_oauth(auth)
      uid = auth.uid
      provider = auth.provider
      snscredential = SnsCredential.where(uid:, provider:).first
      if snscredential.present?
        user = with_sns_data(auth, snscredential)[:user]
        sns = snscredential
      else
        user = without_sns_data(auth)[:user]
        sns = without_sns_data(auth)[:sns]
      end
      { user:, sns: } # ハッシュ形式でreturn
    end
  end
end
