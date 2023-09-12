require "active_support/concern"

module EpisodeMedia
  extend ActiveSupport::Concern

  def complete_media
    contents.complete_or_replaced.group_by(&:position).values.map(&:first)
  end

  # TODO: not ideal, but we need to ensure this stays true forever, after the
  # first time the episode is written to any feed. for now, just assume that
  # takes about an hour.
  def complete_media?
    if published? && published_at < 1.hour.ago
      complete_media.any?
    else
      media_ready?
    end
  end

  def no_media?
    medium.nil? && segment_count.nil? && !media?
  end

  def media
    contents.reject(&:marked_for_destruction?)
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
        existing[position]&.first&.mark_for_replacement
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

  def media?
    media.any?
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
