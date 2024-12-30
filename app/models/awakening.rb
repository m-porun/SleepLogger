class Awakening < ApplicationRecord
  belongs_to :sleep_log, dependent: :destroy

  validates :awakenings_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
