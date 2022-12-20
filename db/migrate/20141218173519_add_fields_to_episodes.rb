class AddFieldsToEpisodes < ActiveRecord::Migration[4.2]
  def change
    remove_column :episodes, :author, :string
    add_column :episodes, :author_name, :string
    add_column :episodes, :author_email, :string
    add_column :episodes, :audio_file_size, :integer
    add_column :episodes, :audio_file_type, :string
  end
end
