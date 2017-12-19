# encoding: utf-8
require 'active_support/concern'

# an uploaded file is moved from temp location to final dest via fixer
module ImportUtils
  extend ActiveSupport::Concern

  included do
    include Announce::Publisher
    include PRXAccess
    include Rails.application.routes.url_helpers
  end

  def enclosure_url(entry)
    url = entry[:feedburner_orig_enclosure_link] || entry[:enclosure].try(:url)
    clean_string(url)
  end

  def explicit(str)
    return nil if str.blank?
    explicit = clean_string(str).downcase
    if %w(true yes).include?(explicit)
      explicit = 'explicit'
    elsif %w(no false).include?(explicit)
      explicit = 'clean'
    end
    explicit
  end

  def person(arg)
    return nil if arg.blank?

    email = name = nil
    if arg.is_a?(Hash)
      email = clean_string(arg[:email])
      name = clean_string(arg[:name])
    else
      s = clean_string(arg)
      if match = s.match(/(.+) \((.+)\)/)
        email = match[1]
        name = match[2]
      else
        name = s
      end
    end

    { name: name, email: email }
  end

  def clean_string(str)
    return nil if str.blank?
    return str if !str.is_a?(String)
    str.strip
  end

  def clean_text(text)
    return nil if text.blank?
    result = remove_feedburner_tracker(text)
    sanitize_html(result)
  end

  def remove_feedburner_tracker(str)
    return nil if str.blank?
    regex = /<img src="http:\/\/feeds\.feedburner\.com.+" height="1" width="1" alt=""\/>/
    str.sub(regex, '').strip
  end

  def sanitize_html(text)
    return nil if text.blank?
    sanitizer = Rails::Html::WhiteListSanitizer.new
    sanitizer.sanitize(Loofah.fragment(text).scrub!(:prune).to_s).strip
  end

  def announce_image(image)
    announce('image', 'create', Api::Msg::ImageRepresenter.new(image).to_json)
  end

  def announce_audio(audio)
    announce('audio', 'create', Api::Msg::AudioFileRepresenter.new(audio).to_json)
  end
end
