class CreateEpisodes < ActiveRecord::Migration[4.2]
  def change
    create_table :episodes do |t|
      t.timestamps
      t.references :podcast
      t.string :title
      t.text :description
      t.string :link
      t.string :author
      t.date :pub_date
      t.string :categories
      t.string :audio_file
      t.string :comments
      t.string :subtitle
      t.text :summary
      t.boolean :explicit
      t.integer :duration
      t.string :keywords
    end
  end
end
