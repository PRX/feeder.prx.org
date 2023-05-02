require "active_support/concern"
require "prx_access"

module ImportUtils
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  def enclosure_url(entry)
    url = entry[:feedburner_orig_enclosure_link] || enclosure_url_from_entry(entry)
    clean_string(url)
  end

  def default_episode_url(episode)
    # TODO no access to the story id here, so we can't build the url
    # path = "#{story.class.name.underscore.pluralize}/#{story.id}"
    #  ENV['PRX_HOST'].nil? ? nil : "https://#{ENV['PRX_HOST']}/#{path}"
    nil
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

    {name: name, email: email}
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
    str.sub(regex, "").strip
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

  private

  def enclosure_url_from_entry(entry)
    return nil unless entry.key?(:enclosure)
    entry[:enclosure][:url]
  end
end
