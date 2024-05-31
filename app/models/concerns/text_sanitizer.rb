require "active_support/concern"
require "loofah"

module TextSanitizer
  extend ActiveSupport::Concern

  def sanitize_white_list(text)
    return nil if text.blank?
    sanitizer = Rails::Html::WhiteListSanitizer.new
    sanitizer.sanitize(Loofah.fragment(text).scrub!(:prune).to_s)
  end

  def sanitize_links_only(text)
    return nil if text.blank?
    scrubber = Rails::Html::PermitScrubber.new
    scrubber.tags = %w[a]
    scrubber.attributes = %w[href target nofollow]
    Loofah.fragment(text).scrub!(:prune).scrub!(scrubber).to_s
  end

  def sanitize_text_only(text)
    return nil if text.blank?
    Loofah.fragment(text).scrub!(:prune).text(encode_special_chars: false)
  end

  def sanitize_keywords(kws, strict)
    Array(kws)
      .map { |kw| sanitize_keyword(kw, kw.length, strict) }
      .uniq(&:downcase)
      .reject(&:blank?)
  end

  def sanitize_keyword(kw, max_length, strict)
    if strict
      kw.to_s.downcase.gsub(/[^ a-z0-9_-]/, "").gsub(/\s+/, " ").strip.slice(0, max_length)
    else
      kw.strip.slice(0, max_length)
    end
  end
end
