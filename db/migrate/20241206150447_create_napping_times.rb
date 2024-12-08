class CreateNappingTimes < ActiveRecord::Migration[7.2]
  def change
    create_table :napping_times do |t|
      t.references :sleep_log, foreign_key: true
      t.integer :napping_time

      t.timestamps
    end
  end
end
