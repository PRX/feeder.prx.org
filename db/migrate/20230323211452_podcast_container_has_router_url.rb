class PodcastContainerHasRouterUrl < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_podcast_containers, :enclosure_url, :text

    reversible do |dir|
      dir.up do
        execute("UPDATE apple_podcast_containers SET enclosure_url = source_url;")
      end
    end
  end
end
