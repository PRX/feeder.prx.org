class CreatePodcasts < ActiveRecord::Migration[4.2]
  def change
    create_table :podcasts do |t|
      t.timestamps
      t.string :title, null: false
      t.string :link, null: false
      t.text :description
      t.string :language
      t.string :managing_editor
      t.date :pub_date
      t.date :last_build_date
      t.string :categories
      t.boolean :explicit
      t.string :subtitle
      t.string :summary
      t.string :keywords
      t.string :update_period
      t.integer :update_value
      t.date :update_base
    end
  end
end
