class AddEpisodeTemplate < ActiveRecord::Migration
  def change
    add_column :episodes, :prx_audio_version_uri, :string
    add_column :episodes, :audio_version, :string
    add_column :episodes, :segment_count, :integer
  end
end
