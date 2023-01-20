class CreateTasks < ActiveRecord::Migration[4.2]
  def change
    create_table :tasks do |t|
      t.references :owner, polymorphic: true, index: true

      t.string :type
      t.integer :status, index: true, default: 0, null: false
      t.datetime :logged_at
      t.string :job_id, index: true
      t.text :options
      t.text :result

      t.timestamps null: false
    end
  end
end
