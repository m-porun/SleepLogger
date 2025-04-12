class NappingTime < ApplicationRecord
  belongs_to :sleep_log

  validates :napping_time, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
