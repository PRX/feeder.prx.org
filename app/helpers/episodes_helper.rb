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

  # Delivery status of the episode in each feed delivering it through the
  # integration, keyed by feed. Empty when no feed does.
  def episode_integration_statuses(episode, integration)
    episode.integration_feeds(integration).index_with { |feed| feed_integration_status(episode, integration, feed) }
  end

  # Status for an episode no feed of the integration delivers.
  def episode_integration_placeholder_status(episode)
    episode.draft? ? "draft" : "not_publishable"
  end

  def episode_integration_updated_at(episode, integration, feed)
    integration_episode = feed.integration_episode(episode, integration)
    return episode.updated_at unless integration_episode

    integration_episode.sync_log&.updated_at ||
      integration_episode.delivery_status&.created_at ||
      episode.updated_at
  end

  # Public feeds of the episode with Apple HLS video turned on.
  def episode_apple_hls_feeds(episode)
    episode.feeds.select { |feed| feed.public? && feed.apple_hls_config&.enabled? }
  end

  def episode_integration_label(name, feed)
    "#{name} (#{feed.label})"
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
    status = episode.media_status
    if status == "invalid"
      "error"
    elsif status == "incomplete" && episode.published_at.present?
      "incomplete-published"
    else
      status
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

  def episode_media_updated_at(episode)
    episode_all_media(episode).maximum(:updated_at)
  end

  def episode_all_media(episode)
    episode.media.append(episode.uncut).compact.reject(&:new_record?)
  end

  def episode_category_button_class(episode, value)
    if episode.categories.include?(value)
      "btn-primary"
    else
      "btn-light"
    end
  end

  def episode_transcript_options
    Transcript.formats.keys.map { |k| [I18n.t("helpers.label.transcript.formats.#{k}"), k] }
  end

  private

  def feed_integration_status(episode, integration, feed)
    integration_episode = feed.integration_episode(episode, integration)
    return "disconnected" unless integration_episode

    status = integration_episode.delivery_status(true)

    if !status
      "disconnected"
    elsif status.new_record?
      "new"
    elsif !status.uploaded?
      "incomplete"
    elsif integration_episode.error_state?
      "error"
    elsif !status.delivered?
      integration_episode.processing_status_label
    else
      "complete"
    end
  end
end
