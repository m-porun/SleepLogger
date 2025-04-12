class Comment < ApplicationRecord
  belongs_to :sleep_log

  validates :comment, length: { maximum: 42 }
end
