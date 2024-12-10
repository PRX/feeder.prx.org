require "active_support/concern"

module EpisodeMedia
  extend ActiveSupport::Concern

  included do
    enum :medium, [:audio, :uncut, :video, :override], prefix: true

    # NOTE: this just-in-time creates new media versions
    # TODO: convert to sql, so we don't have to load/check every episode?
    # TODO: stop loading non-latest media versions
    scope :feed_ready, -> { includes(media_versions: :media_resources).select { |e| e.feed_ready? } }

    has_many :media_versions, -> { order("created_at DESC") }, dependent: :destroy
    has_many :contents, -> { order("position ASC, created_at DESC") }, autosave: true, dependent: :destroy, inverse_of: :episode
    has_one :uncut, -> { order("created_at DESC") }, autosave: true, dependent: :destroy, inverse_of: :episode
    has_one :external_media_resource, -> { order("created_at DESC") }, autosave: true, dependent: :destroy, inverse_of: :episode

    accepts_nested_attributes_for :contents, allow_destroy: true, reject_if: ->(c) { c[:id].blank? && c[:original_url].blank? }
    accepts_nested_attributes_for :uncut, allow_destroy: true, reject_if: ->(u) { u[:id].blank? && u[:original_url].blank? }

    validate :validate_media_ready, if: :strict_validations

    after_save :destroy_out_of_range_contents, if: ->(e) { e.segment_count_previously_changed? }
    after_save :analyze_external_media
  end

  def validate_media_ready
    return unless published_at.present? && media?

    # media must be complete on _initial_ publish
    # otherwise - having files in any status is good enough
    is_ready =
      if published_at_was.blank?
        media_ready?(true) || override_ready?
      elsif medium_uncut?
        uncut.present? && !uncut.marked_for_destruction?
      elsif override?
        external_media_ready?
      else
        media_ready?(false)
      end

    unless is_ready
      errors.add(:base, :media_not_ready, message: "media not ready")
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
    !media? || complete_media? || override_ready?
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
      media.inject(0.0) { |s, c| s + c.duration.to_f } + podcast.try(:duration_padding).to_f
    end
  end

  def media_file_size
    if override?
      external_media_resource&.file_size
    else
      media.inject(0) { |s, c| s + c.file_size.to_i }
    end
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
    states = if override?
      [external_media_resource&.status]
    else
      media.map(&:status).uniq
    end
    if !(%w[started created processing retrying] & states).empty?
      "processing"
    elsif states.any? { |s| s == "error" }
      "error"
    elsif states.any? { |s| s == "invalid" }
      "invalid"
    elsif media_ready? || override_ready?
      "complete"
    end
  end

  def media_url
    media.first.try(:href)
  end

  def override_ready?
    override? && external_media_ready?
  end

  def override_processing?
    override? && !external_media_ready?
  end

  def override?
    medium_override? || !enclosure_override_url.blank?
  end

  def external_media_ready?
    external_media_resource&.status_complete?
  end

  def analyze_external_media
    if enclosure_override_url.blank?
      external_media_resource&.destroy
    elsif enclosure_override_url != external_media_resource&.original_url
      external_media_resource&.destroy
      create_external_media_resource(original_url: enclosure_override_url)
    end
  end
end
