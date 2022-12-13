class AddEpisodeTemplate < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :prx_audio_version_uri, :string
    add_column :episodes, :audio_version, :string
    add_column :episodes, :segment_count, :integer
  end
end
