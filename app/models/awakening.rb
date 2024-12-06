class Awakening < ApplicationRecord
  validates :awakenings_count, numericality: { only_integer: true }

  belongs_to :sleep_log
end
