class HttpHeadValidator < ActiveModel::EachValidator
  include HttpUtil

  def self.skip_validation?
    Rails.env.test?
  end

  def validate_each(rec, attr, val)
    return if self.class.skip_validation?

    if val.present? && HttpUrlValidator.http_url?(val) && (rec.new_record? || rec.changes[attr].present?)
      res = memoize_http_head(val)

      if res.nil? || !res.is_a?(Net::HTTPSuccess)
        rec.errors.add(attr, :unreachable, message: "not http reachable")
      elsif options[:with] && !has_content_type?(res, options[:with])
        rec.errors.add(attr, :invalid_content_type, message: "invalid content type")
      end
    end
  end

  private

  def memoize_http_head(url)
    if @last_http_head == url
      @last_http_res
    else
      @last_http_head = url
      @last_http_res = http_head(url)
    end
  end

  def has_content_type?(res, matching)
    type = res.content_type.to_s.downcase

    if options[:with].is_a?(String) && options[:with] == type
      true
    elsif options[:with].is_a?(Array) && options[:with].include?(type)
      true
    elsif options[:with].is_a?(Regexp) && options[:with].match?(type)
      true
    else
      false
    end
  end
end
