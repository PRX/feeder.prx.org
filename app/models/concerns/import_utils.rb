require "active_support/concern"
require "prx_access"
require "net/http"
require "uri"

module ImportUtils
  extend ActiveSupport::Concern

  class HttpError < StandardError
  end

  CREATED = "created".freeze
  STARTED = "started".freeze
  IMPORTING = "importing".freeze
  COMPLETE = "complete".freeze
  ERROR = "error".freeze
  NOT_FOUND = "not_found".freeze
  BAD_TIMINGS = "bad_timings".freeze
  NO_MEDIA = "no_media".freeze
  DUPLICATE = "duplicate".freeze

  ALL_DONE = [COMPLETE, ERROR, NOT_FOUND, BAD_TIMINGS, NO_MEDIA, DUPLICATE]
  ALL_ERRORS = [ERROR, NOT_FOUND, BAD_TIMINGS, NO_MEDIA, DUPLICATE]

  included do
    include Rails.application.routes.url_helpers

    scope :done, -> { where(status: ALL_DONE) }
    scope :undone, -> { where.not(status: ALL_DONE) }
    scope :errors, -> { where(status: ALL_ERRORS) }
  end

  def done?
    ALL_DONE.include?(status)
  end

  def undone?
    !done?
  end

  def errors?
    ALL_ERRORS.include?(status)
  end

  def enclosure_url(entry)
    url = entry[:feedburner_orig_enclosure_link] || enclosure_url_from_entry(entry)
    clean_string(url)
  end

  def clean_title(str)
    clean_string(str)
  end

  # only 'true'/'false' now allowed
  def explicit(str, default = nil)
    explicit = clean_string(str).try(:downcase)

    if %w[true yes explicit].include?(explicit)
      "true"
    elsif %w[false no clean].include?(explicit)
      "false"
    else
      default
    end
  end

  def person(arg)
    return nil if arg.blank?

    email = name = nil
    if arg.is_a?(Hash)
      email = clean_string(arg[:email])
      name = clean_string(arg[:name])
    else
      s = clean_string(arg)
      if (match = s.match(/(.+) \((.+)\)/))
        email = match[1]
        name = match[2]
      else
        name = s
      end
    end

    {name: name, email: email}.with_indifferent_access
  end

  def clean_string(str)
    return nil if str.blank?
    return str if !str.is_a?(String)
    str.strip
  end

  def clean_text(text)
    return nil if text.blank?
    result = remove_feedburner_tracker(text)
    result = remove_podcastchoices_link(result)
    sanitize_html(result)
  end

  def remove_feedburner_tracker(str)
    return nil if str.blank?
    regex = /<img src="http:\/\/feeds\.feedburner\.com.+" height="1" width="1" alt=""\/>/
    str.sub(regex, "").strip
  end

  def remove_podcastchoices_link(str)
    if str.present?
      str.sub(/(<p>)?learn more about your ad choices.+podcastchoices.com\/adchoices\.?(<\/a>)?(<\/p>)?/i, "").strip
    end
  end

  def sanitize_html(text)
    return nil if text.blank?
    sanitizer = Rails::Html::WhiteListSanitizer.new
    sanitizer.sanitize(Loofah.fragment(text).scrub!(:prune).to_s).strip
  end

  def files_match?(file, url)
    if file.upload_path
      file.upload_path == url
    else
      filename = URI.parse(url || "").path.split("/").last
      file.filename == filename
    end
  end

  def http_get(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "PRX-Feeder-Import/1.0 (Rails-#{Rails.env})"
    res = http.request(req)

    if res.is_a? Net::HTTPSuccess
      res.body
    else
      raise HttpError.new("bad response from #{url}")
    end
  end

  private

  def enclosure_url_from_entry(entry)
    return nil unless entry.key?(:enclosure)
    entry[:enclosure][:url]
  end
end
