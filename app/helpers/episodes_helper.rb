require "text_sanitizer"

module EpisodesHelper
  def episode_metadata_active?
    controller_name == "episodes" && (action_name == "edit" || action_name == "update")
  end

  def episode_itunes_type_options
    Episode::VALID_ITUNES_TYPES.map { |val| [I18n.t("helpers.label.episode.itunes_types.#{val}"), val] }
  end

  def episode_explicit_options
    ["inherit"].concat(Podcast::VALID_EXPLICITS).map do |val|
      [I18n.t("helpers.label.episode.explicit_options.#{val}"), val]
    end
  end

  def episode_apple_status(episode)
    apple_episode = episode.apple_episode
    if !apple_episode
      "not_found"
    elsif apple_episode.needs_delivery?
      "incomplete"
    elsif apple_episode.waiting_for_asset_state?
      "processing"
    elsif apple_episode.audio_asset_state_error?
      "error"
    elsif apple_episode.synced_with_apple?
      "complete"
    else
      "not_found"
    end
  end

  def episode_apple_updated_at(episode)
    episode.apple_sync_log&.updated_at ||
      episode.apple_status&.created_at ||
      episode.updated_at
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
    all_media = episode.media.append(episode.uncut).compact.reject(&:new_record?)

    if all_media.any? { |m| upload_problem?(m) }
      "error"
    elsif all_media.any? { |m| upload_processing?(m) }
      "processing"
    elsif episode.media_ready?(true)
      "complete"
    elsif episode.published_at.present?
      "incomplete-published"
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
      episode_path episode, uploads_retry_params(form)
    end
  end

  def episode_media_label(episode, media)
    medium = episode.medium || "audio"
    I18n.t("helpers.label.media_resource.original_url.#{medium}", position: media.position)
  end

  def episode_medium_options
    Episode.mediums.keys.map { |k| [I18n.t("helpers.label.episode.mediums.#{k}"), k] }
  end

  def episode_category_button_class(episode, value)
    if episode.categories.include?(value)
      "btn-primary"
    else
      "btn-light"
    end
  end
end
