require "text_sanitizer"

module PodcastsHelper
  include TextSanitizer

  RSS_LANGUAGE_CODES = %w[af sq eu be bg ca zh-cn zh-tw hr cs da nl nl-be nl-nl en en-au en-bz en-ca en-ie en-jm en-nz en-ph en-za en-tt en-gb en-us en-zw et fo fi fr fr-be fr-ca fr-fr fr-lu fr-mc fr-ch gl gd de de-at de-de de-li de-lu de-ch el haw hu is in ga it it-it it-ch ja ko mk no pl pt pt-br pt-pt ro ro-mo ro-ro ru ru-mo ru-ru sr sk sl es es-ar es-bo es-cl es-co es-cr es-do es-ec es-sv es-gt es-hn es-mx es-ni es-pa es-py es-pe es-pr es-es es-uy es-ve sv sv-fi sv-se tr uk]

  def podcast_integration_status(integration, podcast)
    sync = podcast.public_feed.sync_log(integration)
    if !sync
      "not_found"
    elsif !sync.external_id
      "new"
    elsif sync.updated_at <= podcast.updated_at
      "incomplete"
    else
      "complete"
    end
  end

  def podcast_integration_updated_at(integration, podcast)
    podcast.public_feed.sync_log(integration)&.updated_at || podcast.updated_at
  end

  def feed_description(feed, podcast)
    [feed.description, podcast.description].detect { |d| d.present? } || ""
  end

  def episode_description(episode, feed)
    description = if episode.podcast.has_apple_feed?
      episode.description_safe
    else
      episode.description_with_default
    end

    if feed.episode_footer.present?
      footer_text = "\n\n#{feed.episode_footer}"
      description = description.truncate_bytes(Episode::MAX_DESCRIPTION_BYTES - footer_text.bytesize)
      description += footer_text
    end

    description
  end

  def episode_title(episode, feed)
    if episode.podcast.has_apple_feed?
      episode.title_safe
    else
      episode.title
    end
  end

  def episode_guid(episode, feed)
    if feed.unique_guids?
      "#{episode.item_guid}_#{feed.id}"
    else
      episode.item_guid
    end
  end

  def full_contact(type, item)
    name = item.try("#{type}_name")
    email = item.try("#{type}_email")
    result = nil
    if !email.blank?
      result = email
      result = "#{result} (#{name})" if !name.blank?
    end
    result
  end

  def first_nonblank(type, items)
    items.find { |item| !item.send(type.to_s).blank? }
  end

  def show_itunes_summary?(model)
    model.description.present?
  end

  def itunes_summary(model)
    sanitize_links_only(model.description || "")
  end

  def podcast_settings_active?
    parts = request.path.split("/").select(&:present?)

    # don't include podcast#show, or any episodes/feeds paths
    parts[0] == "podcasts" && parts[2] && parts[2] != "episodes" && parts[2] != "feeds" && parts[2] != "metrics"
  end

  def podcast_metadata_active?
    parts = request.path.split("/").select(&:present?)

    # either on #edit OR updating #show
    parts[0] == "podcasts" && (parts[2] == "edit" || (parts.count == 2 && action_name == "update"))
  end

  def podcast_explicit_options
    Podcast::VALID_EXPLICITS.map { |val| [I18n.t("helpers.label.podcast.explicits.#{val}"), val] }
  end

  def podcast_serial_order_options
    [false, true].map { |val| [I18n.t("helpers.label.podcast.serial_orders.#{val}"), val] }
  end

  def podcast_destroy_image_path(podcast, feed_form, image_form)
    if podcast.new_record?
      new_podcast_path(podcast, uploads_destroy_params(feed_form, image_form))
    else
      edit_podcast_path(podcast, uploads_destroy_params(feed_form, image_form))
    end
  end

  def podcast_retry_image_path(podcast, feed_form, image_form)
    if podcast.new_record?
      new_podcast_path(podcast, uploads_retry_params(feed_form, image_form))
    else
      podcast_path(podcast, uploads_retry_params(feed_form, image_form))
    end
  end

  def rss_language_options(podcast)
    if RSS_LANGUAGE_CODES.include?(podcast.language) || podcast.language.nil?
      RSS_LANGUAGE_CODES.map { |val| [I18n.t("lang_code.#{val}"), val] }.sort
    else
      RSS_LANGUAGE_CODES.map { |val| [I18n.t("lang_code.#{val}"), val] }.sort.concat([[I18n.t("lang_code.#{podcast.language}"), podcast.language]])
    end
  end

  def disable_non_compliant_language(language)
    if RSS_LANGUAGE_CODES.include?(language)
      nil
    else
      language
    end
  end

  def subscribe_link_platform_label(link)
    I18n.t("helpers.label.podcast.subscribe_link.#{link.platform}")
  end

  def subscribe_link_id_label(link)
    if link.uses_apple_id?
      I18n.t("helpers.label.podcast.subscribe_link.id.apple")
    elsif link.uses_unique_id?
      I18n.t("helpers.label.podcast.subscribe_link.id.unique", platform: subscribe_link_platform_label(link))
    elsif link.uses_feed_url?
      I18n.t("helpers.label.podcast.subscribe_link.id.feed")
    elsif link.uses_podcast_guid?
      I18n.t("helpers.label.podcast.subscribe_link.id.guid")
    elsif link.uses_pod_index_id?
      I18n.t("helpers.label.podcast.subscribe_link.id.pod_index")
    end
  end

  def subscribe_link_help(link)
    if link.uses_apple_id?
      I18n.t("podcast_engagement.form_subscribe_links.help.apple")
    elsif link.uses_unique_id?
      I18n.t("podcast_engagement.form_subscribe_links.help.unique", platform: subscribe_link_platform_label(link))
    elsif link.uses_feed_url?
      I18n.t("podcast_engagement.form_subscribe_links.help.feed")
    elsif link.uses_podcast_guid?
      I18n.t("podcast_engagement.form_subscribe_links.help.guid")
    elsif link.uses_pod_index_id?
      I18n.t("podcast_engagement.form_subscribe_links.help.pod_index")
    end
  end

  def subscribe_link_options(podcast)
    selected = podcast.subscribe_links.select(&:persisted?).map { |sl| sl.platform }

    SubscribeLink::PLATFORMS.filter { |p| !selected.include?(p) }.map { |p| {platform: p, icon: p.split("_").first} }
  end

  def subscribe_link_external_id(podcast, platform)
    if SubscribeLink::APPLE_PLATFORMS.include?(platform) && podcast.subscribe_links.with_apple_id.any?
      podcast.subscribe_links.with_apple_id.first.external_id
    elsif SubscribeLink::FEED_PLATFORMS.include?(platform)
      podcast.public_url
    elsif SubscribeLink::GUID_PLATFORMS.include?(platform)
      podcast.guid
    else
      "NEW_EXTERNAL_ID"
    end
  end
end
