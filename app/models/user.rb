class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, uniqueness: true
  # ユーザーを削除したら、睡眠記録も一緒に消える
  has_many :sleep_logs, dependent: :destroy
end
