class CreateComments < ActiveRecord::Migration[7.2]
  def change
    create_table :comments do |t|
      t.references :sleep_log, foreign_key: true
      t.text :comment
      t.timestamps
    end
  end
end
