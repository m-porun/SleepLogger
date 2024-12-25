class SleepLog < ApplicationRecord
  belongs_to :user
  has_one :awakening
  has_one :napping_time
  has_one :comment

  accepts_nested_attributes_for :awakening
  accepts_nested_attributes_for :comment
  accepts_nested_attributes_for :napping_time
end
