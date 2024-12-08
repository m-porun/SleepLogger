class FixUserReferencesInSleepLogs < ActiveRecord::Migration[7.2]
  def change
    remove_reference :sleep_logs, :users, foreign_key: true
    add_reference :sleep_logs, :user, foreign_key: true
  end
end
