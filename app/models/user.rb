class User < ApplicationRecord
  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, uniqueness: true
  # ユーザーを削除したら睡眠記録も一緒に消える
  has_many :sleep_logs, dependent: :destroy
end