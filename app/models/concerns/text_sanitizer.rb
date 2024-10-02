require "active_support/concern"
require "loofah"

module TextSanitizer
  extend ActiveSupport::Concern

  def sanitize_white_list(text)
    return nil if text.blank?
    sanitizer = Rails::Html::WhiteListSanitizer.new
    text = sanitizer.sanitize(Loofah.fragment(text).scrub!(:prune).to_s)
    clean_whitespace(text)
  end

  def sanitize_links_only(text)
    return nil if text.blank?
    scrubber = Rails::Html::PermitScrubber.new
    scrubber.tags = %w[a]
    scrubber.attributes = %w[href target nofollow]
    text = add_newlines_to_tags(text)
    text = Loofah.fragment(text).scrub!(:prune).scrub!(scrubber).to_s
    clean_whitespace(text)
  end

  def sanitize_text_only(text)
    return nil if text.blank?
    text = add_newlines_to_tags(text)
    text = Loofah.fragment(text).scrub!(:prune).text(encode_special_chars: false)
    clean_whitespace(text)
  end

  def sanitize_categories(kws, strict)
    Array(kws)
      .map { |kw| sanitize_category(kw, kw.length, strict) }
      .uniq(&:downcase)
      .reject(&:blank?)
  end

  def sanitize_category(kw, max_length, strict)
    if strict
      kw.to_s.downcase.gsub(/[^ a-z0-9_-]/, "").gsub(/\s+/, " ").strip.slice(0, max_length)
    else
      kw.strip.slice(0, max_length)
    end
  end

  def add_newlines_to_tags(text)
    text.gsub(/<p>/i, "\n<p>")
      .gsub(/<\/p>/i, "</p>\n")
      .gsub(/<div>/i, "\n<div>")
      .gsub(/<\/div>/i, "</div>\n")
      .gsub(/<br>/i, "\n<br>")
      .gsub(/<br\s*\/>/i, "\n<br>")
  end

  def clean_whitespace(text)
    text.tr("\r", "\n")
      .gsub(/\s*\n\s*/, "\n")
      .squeeze(" ")
      .strip
  end
end
