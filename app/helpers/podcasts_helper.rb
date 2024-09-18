require "text_sanitizer"

module PodcastsHelper
  include TextSanitizer

  RSS_LANGUAGE_CODES = %w[af sq eu be bg ca zh-cn zh-tw hr cs da nl nl-be nl-nl en en-au en-bz en-ca en-ie en-jm en-nz en-ph en-za en-tt en-gb en-us en-zw et fo fi fr fr-be fr-ca fr-fr fr-lu fr-mc fr-ch gl gd de de-at de-de de-li de-lu de-ch el haw hu is in ga it it-it it-ch ja ko mk no pl pt pt-br pt-pt ro ro-mo ro-ro ru ru-mo ru-ru sr sk sl es es-ar es-bo es-cl es-co es-cr es-do es-ec es-sv es-gt es-hn es-mx es-ni es-pa es-py es-pe es-pr es-es es-uy es-ve sv sv-fi sv-se tr uk]

  def feed_description(feed, podcast)
    [feed.description, podcast.description].detect { |d| d.present? } || ""
  end

  def episode_description(episode)
    desc = episode.description_with_default
    if episode.podcast.has_apple_config?
      desc = episode.description.truncate_bytes(4000, omission: "")
    end
    desc
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
    model.summary.present? || model.description.present?
  end

  def itunes_summary(model)
    if model.summary.present?
      model.summary
    else
      sanitize_links_only(model.description || "")
    end
  end

  def podcast_settings_active?
    parts = request.path.split("/").select(&:present?)

    # don't include podcast#show, or any episodes/feeds paths
    parts[0] == "podcasts" && parts[2] && parts[2] != "episodes" && parts[2] != "feeds"
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
end
