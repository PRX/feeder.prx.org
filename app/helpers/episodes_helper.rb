require "text_sanitizer"

module EpisodesHelper
  def episode_metadata_active?
    controller_name == "episodes" && (action_name == "edit" || action_name == "update")
  end

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

  def episode_media_status(episode)
    all_media = episode.media.append(episode.uncut).compact

    if all_media.any? { |m| upload_problem?(m) }
      "error"
    elsif all_media.any? { |m| upload_processing?(m) }
      "processing"
    elsif episode.media_ready?(true)
      "complete"
    else
      "incomplete"
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

  def episode_media_duration(media)
    (media.duration || 0).to_time_summary
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

  def episode_media_label(episode, media)
    medium = episode.medium || "audio"
    I18n.t("helpers.label.media_resource.original_url.#{medium}", position: media.position)
  end

  def episode_medium_options
    Episode.mediums.keys.map { |k| [I18n.t("helpers.label.episode.mediums.#{k}"), k] }
  end
end
