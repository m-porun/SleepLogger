class SleepLog < ApplicationRecord
  belongs_to :user
  has_one :awakening
  has_one :napping_time
  has_one :comment
end
