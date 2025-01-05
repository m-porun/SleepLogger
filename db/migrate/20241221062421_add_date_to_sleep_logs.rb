class AddDateToSleepLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :sleep_logs, :date, :date # date型のdateカラムをSleepLogモデルに追加する
  end
end
