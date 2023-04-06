require "text_sanitizer"

module EpisodesHelper
  def episode_itunes_type_options
    Episode::VALID_ITUNES_TYPES.map { |val| [I18n.t("helpers.label.episode.itunes_types.#{val}"), val] }
  end

  def episode_status_class(episode)
    case episode.publishing_status_was
    when "draft"
      "warning"
    when "scheduled"
      "success text-white"
    else
      "primary text-white"
    end
  end

  def episode_border_color(episode)
    case episode.publishing_status
    when "draft"
      "warning"
    when "scheduled"
      "success"
    else
      "primary"
    end
  end

  def episode_publishing_status_options
    PublishingStatus::STATUSES.map { |val| [I18n.t("helpers.label.episode.publishing_statuses.#{val}"), val] }
  end

  def episodes_path_or_podcast_episodes_path(podcast_id = nil)
    if podcast_id.present?
      podcast_episodes_path(podcast_id)
    else
      episodes_path
    end
  end

  def episode_audio_segment_positions(episode)
    # TODO: is this fine? faking that segment_count is required, just for the feeder UI
    if episode.valid? && episode.segment_count.blank?
      episode.errors.add(:segment_count, "Can't be blank")
    end

    positions =
      if episode.errors[:segment_count].present?
        []
      elsif params.dig(:episode, :prev_segment_count).blank?
        1..Episode::MAX_SEGMENT_COUNT
      else
        # turbo stream: only refresh subset of positions
        prev = params.dig(:episode, :prev_segment_count).to_i
        curr = episode.segment_count
        ([prev, curr].compact.min + 1)..Episode::MAX_SEGMENT_COUNT
      end

    # find/build contents for each in-range position
    positions.map do |p|
      if p <= episode.segment_count.to_i
        c = episode.contents.find { |c| c.position == p }
        c ||= episode.contents.new(position: p)
        [p, c]
      else
        [p, nil]
      end
    end.to_h
  end

  def episode_filled_contents(episode)
    positions = @episode.contents.reject(&:marked_for_destruction?).map(&:position)
    missing = (episode.segment_range.to_a - positions).map { |p| Content.new(position: p) }
    (@episode.contents + missing).sort_by(&:position).group_by(&:position)
  end
end
