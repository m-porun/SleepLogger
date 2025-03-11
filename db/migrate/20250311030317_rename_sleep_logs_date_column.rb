class RenameSleepLogsDateColumn < ActiveRecord::Migration[7.2]
  def change
    rename_column :sleep_logs, :date, :sleep_date
  end
end
