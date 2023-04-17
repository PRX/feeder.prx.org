require "active_support/concern"
require "prx_access"

# an uploaded file is moved from temp location to final dest via fixer
module ImportUtils
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  def enclosure_url(entry)
    url = entry[:feedburner_orig_enclosure_link] || enclosure_url_from_entry(entry)
    clean_string(url)
  end

  def default_story_url(story)
    StoryDistributions::EpisodeDistribution.default_story_url(story)
  end

  def clean_title(str)
    str = clean_string(str)
    return str if str.length <= 255
    truncated = str[0..254]

    e = RuntimeError.new("ImportUtils: #{self.class.name}[id:#{try(:id)}] having title string length of #{str.length} exceeds column length of 255: #{truncated}")
    e.set_backtrace(caller)
    NewRelic::Agent.notice_error(e)

    clean_string(truncated)
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

  def remove_utf8_4byte(str)
    str.each_char.select { |char| char.bytesize < 4 }.join("")
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

  def announce(type, action, msg)
    Rails.logger.error("announce #{type} #{action} #{msg}")
  end

  def announce_image(image)
    announce("image", "create", Api::Msg::ImageRepresenter.new(image).to_json)
    image.process!
  end

  def announce_audio(audio)
    announce("audio", "create", Api::Msg::AudioFileRepresenter.new(audio).to_json)
    audio.process!
  end

  def remind_to_unlock(title)
    unless Rails.env.test?
      puts "################################"
      puts "Reminder: #{title} is LOCKED. Unlock in Feeder to publish feed."
      puts "################################"
    end
  end

  private

  def enclosure_url_from_entry(entry)
    return nil unless entry.key?(:enclosure)
    entry[:enclosure][:url]
  end
end
