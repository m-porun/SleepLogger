class Awakening < ApplicationRecord
  belongs_to :sleep_log
  attribute :awakenings_count, :integer

  validates :awakenings_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
