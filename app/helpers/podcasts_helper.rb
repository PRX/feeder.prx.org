require "text_sanitizer"

module PodcastsHelper
  include TextSanitizer

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

  def itunes_category_options
    ITunesCategoryValidator::CATEGORIES.keys
  end

  def itunes_subcategory_options(cat = nil)
    ITunesCategoryValidator::CATEGORIES[cat] || []
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
      edit_podcast_path(podcast, uploads_retry_params(feed_form, image_form))
    end
  end
end
