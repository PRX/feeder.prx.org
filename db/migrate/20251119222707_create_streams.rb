class CreateStreams < ActiveRecord::Migration[7.2]
  def change
    create_table :streams do |t|
      t.references :podcast, index: true, foreign_key: true

      t.string :url
      t.string :status

      t.date :start_date
      t.date :end_date
      t.text :record_days
      t.text :record_hours

      t.string :create_as
      t.integer :expiration

      t.timestamps
      t.timestamp :deleted_at
    end
  end
end
