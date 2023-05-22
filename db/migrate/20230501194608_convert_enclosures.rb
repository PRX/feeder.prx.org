class ConvertEnclosures < ActiveRecord::Migration[7.0]
  def up
    add_column :episodes, :medium, :integer

    # cleanup episodes with both Contents and Enclosures
    MediaResource.where(type: "Enclosure").where("episode_id IN (#{Content.select(:episode_id).to_sql})").delete_all

    # convert enclosures to contents
    MediaResource.where(type: "Enclosure").update_all(type: "Content", position: 1)

    # guess missing mediums from original_urls
    MediaResource.status_complete.where(medium: nil).each do |mr|
      if mr.audio?
        mr.update_column(:medium, "audio")
      elsif mr.video?
        mr.update_column(:medium, "video")
      else
        raise "could not infer medium for original_url = #{mr.original_url}"
      end
    end

    # set episode.medium based on media_resources.medium
    Episode.joins(:contents).where(contents: {medium: "audio"}).update_all(medium: "audio")
    Episode.joins(:contents).where(contents: {medium: "video"}).update_all(medium: "video")
  end

  def down
    Rails.logger.warn "WOH cannot revert content/enclosure changes - just reverting column"
    remove_column :episodes, :medium, :integer
  end
end
