class CreateSleepLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :sleep_logs do |t|
      t.references :user, foreign_key: true
      t.datetime :go_to_bed_at # 昨夜布団に入った時間
      t.datetime :fell_asleep_at # 昨夜眠りについた時間
      t.datetime :woke_up_at # 今朝目覚めた時間
      t.datetime :leave_bed_at # 今朝布団から出た時間

      t.timestamps
    end
  end
end