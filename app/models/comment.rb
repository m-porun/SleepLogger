class Comment < ApplicationRecord
  validates :comment, { maximum: 42 }

  belongs_to :sleep_log
end
