module HttpUtil
  USER_AGENT = "PRX-Feeder-Validator/1.0 (Rails-#{Rails.env})"
  MAX_REDIRECTS = 5
  TIMEOUT = 5.seconds

  def self.http_head(uri_str, **opts)
    uri = URI.parse(uri_str)
    user_agent = opts[:user_agent] || USER_AGENT
    max_redirects = opts[:max_redirects] || MAX_REDIRECTS
    timeout = opts[:timeout] || TIMEOUT

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == "https"
    http.read_timeout = timeout
    http.max_retries = 0

    req = Net::HTTP::Head.new(uri)
    req["User-Agent"] = user_agent
    res = http.request(req)

    if res.is_a?(Net::HTTPRedirection) && max_redirects > 0
      http_head(res[:location], **opts.merge(max_redirects: max_redirects - 1))
    else
      res
    end
  rescue URI::InvalidURIError, Socket::ResolutionError, Net::ReadTimeout
    nil
  end

  def http_head(uri_str, **opts)
    HttpUtil.http_head(uri_str, **opts)
  end
end
