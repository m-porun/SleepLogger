class SleepLog < ApplicationRecord
  belongs_to :user
  has_one :awakening, dependent: :destroy, autosave: true
  has_one :napping_time, dependent: :destroy, autosave: true
  has_one :comment, dependent: :destroy, autosave: true
  # accepts_nested_attributes_for :awakening, :napping_time, :comment

  validates :user_id, presence: true
  validates :sleep_date, uniqueness: { scope: :user_id, message: "はすでに登録されています" } # TODO: schemaファイルにも一意登録すべきでは
end
