class SleepLog < ApplicationRecord
  belongs_to :user
  has_one :awakening, dependent: :destroy
  has_one :napping_time, dependent: :destroy
  has_one :comment, dependent: :destroy
  # accepts_nested_attributes_for :awakening, :napping_time, :comment

  validates :user_id, presence: true
  validates :date, uniqueness: { scope: :user_id, message: "はすでに登録されています" } # TODO: schemaファイルにも一意登録すべきでは
end
