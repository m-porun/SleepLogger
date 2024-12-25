class NappingTime < ApplicationRecord
  validates :napping_time, numericality: { only_integer: true }

  belongs_to :sleep_log, dependent: :destroy
end
