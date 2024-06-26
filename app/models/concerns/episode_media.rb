require "active_support/concern"

module EpisodeMedia
  extend ActiveSupport::Concern

  included do
    # NOTE: this just-in-time creates new media versions
    # TODO: convert to sql, so we don't have to load/check every episode?
    # TODO: stop loading non-latest media versions
    scope :feed_ready, -> { includes(media_versions: :media_resources).select { |e| e.feed_ready? } }
  end

  def feed_ready?
    !media? || complete_media?
  end

  def cut_media_version!
    latest_version = media_versions.first
    latest_media = latest_version&.media_resources || []
    latest_ids = latest_media.map(&:id)

    # backfill media_versions for newly completed media
    if media_ready? && latest_ids != media_ids
      new_version = media_versions.build
      media.each { |m| new_version.media_version_resources.build(media_resource: m) }
      new_version.save!
      new_version
    else
      latest_version
    end
  end

  def media_version_id
    cut_media_version!&.id
  end

  def complete_media
    cut_media_version!&.media_resources || []
  end

  def complete_media?
    complete_media.any?
  end

  def media?
    medium.present? || segment_count.present? || media.present?
  end

  def media
    contents.reject(&:marked_for_destruction?)
  end

  def media_ids
    media.map(&:id)
  end

  # API updates ignore nil attributes
  def media=(files)
    return if files.nil?

    existing = contents.group_by(&:position)
    files = Array(files)

    # update by position
    files.map.with_index(1) do |file, position|
      con = Content.build(file, position)

      if !con
        existing[position]&.each(&:mark_for_destruction)
      elsif con.replace?(existing[position]&.first)
        contents.build(con.attributes.compact)
        existing[position]&.first&.mark_for_destruction
      else
        con.update_resource(existing[position].first)
      end
    end

    # destroy unused positions
    positions = 1..(files&.size.to_i)
    existing.each do |position, contents|
      contents.each(&:mark_for_destruction) unless positions.include?(position)
    end

    # infer episode medium
    current = contents.reject(&:marked_for_destruction?)
    unless medium_uncut?
      if current.all?(&:audio?)
        self.medium = "audio"
      elsif current.all?(&:video?)
        self.medium = "video"
      end
    end
  end

  def media_content_type(feed = nil)
    media_content_type = media.first.try(:mime_type)
    feed_content_type = feed.try(:mime_type)

    # if audio AND feed has a mime type, dovetail will transcode to that
    if (media_content_type || "").starts_with?("audio")
      feed_content_type || media_content_type
    elsif media_content_type
      media_content_type
    else
      "audio/mpeg"
    end
  end

  def video_content_type?(*args)
    media_content_type(*args).starts_with?("video")
  end

  def media_duration
    media.inject(0.0) { |s, c| s + c.duration.to_f } + podcast.try(:duration_padding).to_f
  end

  def media_file_size
    media.inject(0) { |s, c| s + c.file_size.to_i }
  end

  def media_ready?(must_be_complete = true)
    if media.empty?
      false
    elsif must_be_complete && !media.all?(&:status_complete?)
      false
    elsif segment_count.nil?
      media.size == media.map(&:position).max
    else
      media.size >= segment_count
    end
  end

  def media_status
    states = media.map(&:status).uniq
    if !(%w[started created processing retrying] & states).empty?
      "processing"
    elsif states.any? { |s| s == "error" }
      "error"
    elsif states.any? { |s| s == "invalid" }
      "invalid"
    elsif media_ready?
      "complete"
    end
  end

  def media_url
    media.first.try(:href)
  end
end
