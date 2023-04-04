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

  def episode_filled_contents(episode)
    positions = @episode.contents.reject(&:marked_for_destruction?).map(&:position)
    missing = (episode.segment_range.to_a - positions).map { |p| Content.new(position: p) }
    (@episode.contents + missing).sort_by(&:position).group_by(&:position)
  end
end
