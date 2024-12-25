class Comment < ApplicationRecord
  validates :comment, length: { maximum: 42 }

  belongs_to :sleep_log, dependent: :destroy
end
