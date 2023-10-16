require "hash_serializer"

class AddTypeToImports < ActiveRecord::Migration[7.0]
  def up
    # unused column
    remove_column :podcast_imports, :account_id

    # change to STI
    add_column :podcast_imports, :type, :string
    add_column :episode_imports, :type, :string
    PodcastImport.update_all(type: "PodcastRssImport")
    EpisodeImport.update_all(type: "EpisodeRssImport")

    # bring episode imports to parity with "config" store
    add_column :episode_imports, :config, :text
    EpisodeRssImport.find_each do |ei|
      entry = HashSerializer.load(ei.entry_before_type_cast)
      audio = HashSerializer.load(ei.audio_before_type_cast)
      ActiveRecord::Base.logger.silence do
        ei.update_column(:config, {entry: entry, audio: audio})
      end
    end
    remove_column :episode_imports, :entry, :text
    remove_column :episode_imports, :audio, :text
  end

  def down
    add_column :podcast_imports, :account_id, :integer
    add_column :episode_imports, :entry, :text
    add_column :episode_imports, :audio, :text
    remove_column :podcast_imports, :type
    remove_column :episode_imports, :type

    # back to 2 hash serialized fields
    EpisodeImport.find_each do |ei|
      config = HashSerializer.load(ei.config_before_type_cast)
      entry = HashSerializer.dump(config[:entry])
      audio = HashSerializer.dump(config[:audio])
      ei.update_columns(entry: entry, audio: audio)
    end
    remove_column :episode_imports, :config
  end
end
