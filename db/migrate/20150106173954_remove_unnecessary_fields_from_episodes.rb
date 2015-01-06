class RemoveUnnecessaryFieldsFromEpisodes < ActiveRecord::Migration
  def change
    remove_column :episodes, :title, :string
    remove_column :episodes, :description, :text
    remove_column :episodes, :link, :string
    remove_column :episodes, :pub_date, :date
    remove_column :episodes, :categories, :string
    remove_column :episodes, :audio_file, :string
    remove_column :episodes, :comments, :string
    remove_column :episodes, :subtitle, :string
    remove_column :episodes, :summary, :text
    remove_column :episodes, :explicit, :boolean
    remove_column :episodes, :duration, :integer
    remove_column :episodes, :keywords, :string
    remove_column :episodes, :author_name, :string
    remove_column :episodes, :author_email, :string
    remove_column :episodes, :audio_file_size, :integer
    remove_column :episodes, :audio_file_type, :string
  end
end
