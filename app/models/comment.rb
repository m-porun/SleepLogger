class Comment < ApplicationRecord
  belongs_to :sleep_log, dependent: :destroy

  validates :comment, length: { maximum: 42 }
end
