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

  def episode_content_duration(content)
    Time.at(content.duration || 0).utc.strftime("%H:%M:%S").sub(/^00:/, "0:")
  end

  def episode_destroy_image_path(episode, form)
    if episode.new_record?
      new_podcast_episode_path episode.podcast_id, uploads_destroy_params(form)
    else
      edit_episode_path episode, uploads_destroy_params(form)
    end
  end

  def episode_retry_image_path(episode, form)
    if episode.new_record?
      new_podcast_episode_path episode.podcast_id, uploads_retry_params(form)
    else
      edit_episode_path episode, uploads_retry_params(form)
    end
  end
end
