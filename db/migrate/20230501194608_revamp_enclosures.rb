class RevampEnclosures < ActiveRecord::Migration[7.0]
  def up
    add_column :episodes, :medium, :integer

    # cleanup episodes with both Contents and Enclosures
    Enclosure.where("episode_id IN (#{Content.select(:episode_id).to_sql})").delete_all

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

    # convert video contents to enclosures, audio enclosures to contents
    Content.where(medium: "video").update_all(type: "Enclosure", position: nil)
    Enclosure.where(medium: "audio").update_all(type: "Content", position: 1)

    # set episode.medium based on media_resources.medium
    Episode.joins(:contents).where(contents: {medium: "audio"}).update_all(medium: "audio")
    Episode.joins(:contents).where(contents: {medium: "video"}).update_all(medium: "video")
    Episode.joins(:enclosures).where(enclosures: {medium: "audio"}).update_all(medium: "audio")
    Episode.joins(:enclosures).where(enclosures: {medium: "video"}).update_all(medium: "video")
  end

  def down
    Rails.logger.warn "WOH cannot revert content/enclosure changes - just reverting column"
    remove_column :episodes, :medium, :integer
  end
end
