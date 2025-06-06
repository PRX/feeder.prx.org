require "active_support/concern"

module EpisodeMedia
  extend ActiveSupport::Concern

  included do
    enum :medium, [:audio, :uncut, :video, :override], prefix: true

    # NOTE: this just-in-time creates new media versions
    # TODO: convert to sql, so we don't have to load/check every episode?
    # TODO: stop loading non-latest media versions
    scope :feed_ready, -> { includes(media_versions: :media_resources).select { |e| e.feed_ready? } }

    validate :validate_media_ready, if: :strict_validations

    after_save :destroy_out_of_range_contents, if: ->(e) { e.segment_count_previously_changed? }
    after_save :create_external_media
  end

  def validate_media_ready
    return unless published_at.present? && media?

    # media must be complete on _initial_ publish
    # otherwise - having files in any status is good enough
    unless enclosure_ready?(published_at_was.blank?)
      errors.add(:base, :media_not_ready, message: "media not ready")
    end
  end

  def enclosure_ready?(must_be_complete = true)
    if override?
      override_ready?(must_be_complete)
    else
      media_ready?(must_be_complete)
    end
  end

  def medium=(new_medium)
    super

    if medium_changed? && medium_was.present?
      if medium_was == "uncut" && medium == "audio"
        uncut&.mark_for_destruction
      elsif medium_was == "audio" && medium == "uncut"
        if (c = contents.first)
          build_uncut.tap do |u|
            u.file_size = contents.first.file_size
            u.duration = contents.first.duration

            # use the feeder cdn url for older completed files
            is_old = (Time.now - c.created_at) > 24.hours
            u.original_url = (c.status_complete? && is_old) ? c.url : c.original_url
          end
        end
        contents.each(&:mark_for_destruction)
      else
        contents.each(&:mark_for_destruction)
      end
    end

    self.segment_count = 1 if medium_video? || medium_override?
  end

  def copy_media(force = false)
    contents.each { |c| c.copy_media(force) }
    images.each { |i| i.copy_media(force) }
    transcript&.copy_media(force)
    uncut&.copy_media(force)
    external_media_resource&.copy_media(force)
  end

  def segment_range
    1..segment_count.to_i
  end

  def build_contents
    segment_range.map do |p|
      contents.find { |c| c.position == p } || contents.build(position: p)
    end
  end

  def destroy_out_of_range_contents
    if segment_count.present? && segment_count.positive?
      contents.where.not(position: segment_range.to_a).destroy_all
    end
  end

  def feed_ready?
    if override?
      override_ready?
    else
      !media? || complete_media?
    end
  end

  def cut_media_version!
    latest_version = media_versions.first
    latest_media = latest_version&.media_resources || []
    latest_ids = latest_media.map(&:id)

    # backfill media_versions for newly completed media
    if media_ready?(true) && latest_ids != media_ids
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

  def uncut=(uncut)
    # if uncut is unchanged or missing, update other attributes
    if (uncut && self.uncut) && (uncut.href.blank? || (self.uncut.href == uncut.href))
      self.uncut.segmentation = uncut.segmentation if uncut.segmentation.present?
    else
      super
    end

    self.medium = if uncut.present?
      "uncut"
    end
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
    if override?
      external_media_resource&.mime_type || "audio/mpeg"
    elsif (media_content_type || "").starts_with?("audio")
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
    if override?
      external_media_resource&.duration
    else
      media_duration_sum + podcast.try(:duration_padding).to_f
    end
  end

  def media_duration_sum
    media.inject(0.0) { |s, c| s + c.duration.to_f }
  end

  def media_file_size
    if override?
      external_media_resource&.file_size
    else
      media_file_size_sum
    end
  end

  def media_file_size_sum
    media.inject(0) { |s, c| s + c.file_size.to_i }
  end

  # must_be_complete=true, is used for:
  #  A) validating the episode Contents are ready-to-go on initial publish
  #  B) helping DTR decide which (old/replaced or new) to serve, via the API "ready_media"
  #  C) cut new media_versions, when all Contents are completed
  #
  # otherwise, just check that this episodes has _enough_ media to stay published.
  # and hopefully/eventually we'll finish processing it, and it will all be valid:
  #  1) medium=audio ... must have enough files (handling segment_count=nil episodes)
  #  2) medium=video ... same, but we enforce segment_count=1 elsewhere
  #  3) medium=uncut ... must have a non-deleted Uncut, which we'll process/slice later
  def media_ready?(must_be_complete = true)
    if !must_be_complete && medium_uncut?
      uncut.present? && !uncut.marked_for_destruction?
    elsif media.empty?
      false
    elsif segment_count.nil? && (media.size < media.map(&:position).max)
      false
    elsif media.size < segment_count.to_i
      false
    elsif must_be_complete
      media.all?(&:status_complete?)
    else
      true
    end
  end

  def media_status
    states = if override?
      [external_media_resource&.status]
    else
      ([uncut] + media).compact.map(&:status).uniq
    end

    if !(%w[started created processing retrying] & states).empty?
      "processing"
    elsif states.any? { |s| s == "error" }
      "error"
    elsif states.any? { |s| s == "invalid" }
      "invalid"
    elsif enclosure_ready?(true)
      "complete"
    else
      "incomplete"
    end
  end

  def media_url
    media.first.try(:href)
  end

  def override_ready?(must_be_complete = true)
    if override?
      if must_be_complete
        external_media_resource&.status_complete?
      else
        !enclosure_override_url.blank?
      end
    else
      false
    end
  end

  def override?
    medium_override? || !enclosure_override_url.blank?
  end

  def create_external_media
    if enclosure_override_url.blank?
      external_media_resource&.destroy
    elsif enclosure_override_url != external_media_resource&.original_url
      external_media_resource&.destroy
      create_external_media_resource(original_url: enclosure_override_url)
    end
  end
end
