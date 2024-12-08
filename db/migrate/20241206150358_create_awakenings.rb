class CreateAwakenings < ActiveRecord::Migration[7.2]
  def change
    create_table :awakenings do |t|
      t.references :sleep_log, foreign_key: true
      t.integer :awakenings_count

      t.timestamps
    end
  end
end
