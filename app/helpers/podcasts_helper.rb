require "text_sanitizer"

module PodcastsHelper
  include TextSanitizer

  RSS_LANGUAGE_CODES = %w[af sq eu be bg ca zh-cn zh-tw hr cs da nl nl-be nl-nl en en-au en-bz en-ca en-ie en-jm en-nz en-ph en-za en-tt en-gb en-us en-zw et fo fi fr fr-be fr-ca fr-fr fr-lu fr-mc fr-ch gl gd de de-at de-de de-li de-lu de-ch el haw hu is in ga it it-it it-ch ja ko mk no pl pt pt-br pt-pt ro ro-mo ro-ro ru ru-mo ru-ru sr sk sl es es-ar es-bo es-cl es-co es-cr es-do es-ec es-sv es-gt es-hn es-mx es-ni es-pa es-py es-pe es-pr es-es es-uy es-ve sv sv-fi sv-se tr uk]

  PUBLISH_LANGUAGE_CODES = %w[ach ady af af-na af-za ak ar ar-ar ar-ma ar-sa ay-bo az az-az be-by bg bg-bg bn bn-in bn-bd bs-ba ca ca-es cak ck-us cs cs-cz cy cy-gb da da-dk de de-at de-de de-ch dsb el el-gr en en-gb en-au en-ca en-ie en-in en-pi en-ud en-us en-za en@pirate eo eo-eo es es-ar es-419 es-cl es-co es-ec es-es es-la es-ni es-mx es-us es-ve et et-ee eu eu-es fa fa-ir fb-lt ff fi fi-fi fo-fo fr fr-ca fr-fr fr-be fr-ch fy-nl ga ga-ie gl gl-es gn-py gu-in gx-gr he he-il hi hi-in hr hr-hr hsb ht hu hu-hu hy-am id id-id is is-is it it-it ja ja-jp jv-id ka-ge kk-kz km km-kh kab kn kn-in ko ko-kr ku-tr la la-va lb li-nl lt lt-lt lv lv-lv mai mg-mg mk mk-mk ml ml-in mn-mn mr mr-in ms ms-my mt mt-mt my no nb nb-no ne ne-np nl nl-be nl-nl nn-no oc or-in pa pa-in pl pl-pl ps-af pt pt-br pt-pt qu-pe rm-ch ro ro-ro ru ru-ru sa-in se-no si-lk sk sk-sk sl sl-si so-so sq sq-al sr sr-rs su sv sv-se sw sw-ke ta ta-in te te-in tg tg-tj th th-th tl tl-ph tlh tr tr-tr tt-ru uk uk-ua ur ur-pk uz uz-uz vi vi-vn xh-za yi yi-de zh zh-hans zh-hant zh-cn zh-hk zh-sg zh-tw zu-za]

  NON_COMPLIANT_CODES = PUBLISH_LANGUAGE_CODES.filter do |code|
    !RSS_LANGUAGE_CODES.include?(code)
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

  def rss_language_options
    PUBLISH_LANGUAGE_CODES.map { |val| [I18n.t("lang_code.#{val}"), val] }.sort
  end
end
