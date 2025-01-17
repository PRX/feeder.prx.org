class RedirectPrefixValidator < ActiveModel::EachValidator
  TEST_AGENT = "PRX-Feeder-Validator/1.0 (Rails-#{Rails.env})"
  TEST_URL = "dovetail.prxu.org/zero.mp3"
  DEFAULT_MAX_JUMPS = 10

  def self.skip_validation?
    Rails.env.test?
  end

  def validate_each(record, attribute, value)
    if value.present? && record.changes[attribute].present? && !self.class.skip_validation?
      success, jumps = head_request(File.join(value, TEST_URL))
      max_jumps = options[:max_jumps] || DEFAULT_MAX_JUMPS

      if !success
        record.errors.add(attribute, :unreachable, message: "prefix not reachable")
      elsif jumps > max_jumps
        record.errors.add(attribute, :too_many_redirects, message: "too many redirects")
      end
    end
  end

  private

  def head_request(uri_str, jumps = 0)
    uri = URI.parse(uri_str)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    req = Net::HTTP::Head.new(uri)
    req["User-Agent"] = TEST_AGENT
    res = http.request(req)

    if res.is_a?(Net::HTTPRedirection)
      head_request(res[:location], jumps + 1)
    elsif res.is_a?(Net::HTTPSuccess)
      [true, jumps]
    else
      [false, jumps]
    end
  rescue URI::InvalidURIError, Socket::ResolutionError
    [false, jumps]
  end
end
