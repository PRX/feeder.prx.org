require 'uri'
require 'excon'
require 'xmlrpc/parser'

class WeblogPinger

  PING_FEEDBURNER_URL = 'http://ping.feedburner.com'

  def self.ping(options = {})
    new.ping(options)
  end

  def ping(options = {})
    ping_url = options[:ping_url] || PING_FEEDBURNER_URL
    feed_url = options[:feed_url]
    feed_name = options[:feed_name] || get_feed_name(feed_url)

    request_body = build_request_body(feed_name, feed_url)

    conn = connection(ping_url)
    ping_full_path = URI.parse(ping_url).request_uri
    response = conn.post do |req|
      req.url ping_full_path
      req.headers['Content-Type'] = 'text/xml'
      req.body = request_body
    end

    # why reinvent the wheel?
    parser = XMLRPC::XMLParser::REXMLStreamParser::StreamListener.new
    parser.parse(response.body)
    parser.params.try(:first)
  rescue StandardError => err
    Rails.logger.error params.inspect
    { 'flerror' => true, 'message' => err }
  end

  def build_request_body(feed_name, feed_url)
    %Q(<?xml version="1.0" encoding="iso-8859-1"?>
  <methodCall>
    <methodName>weblogUpdates.ping</methodName>
    <params>
      <param>
        <value>
          <string>#{feed_name}</string>
        </value>
      </param>
      <param>
        <value>
          <string>#{feed_url}</string>
        </value>
      </param>
    </params>
  </methodCall>)
  end

  def get_feed_name(url)
    url.split('/').last
  end

  def connection(url)
    conn = Faraday.new(url: url) do |faraday|
      # faraday.request  :url_encoded # form-encode POST params
      faraday.response :logger      # log requests to STDOUT
      faraday.adapter  :excon       # make requests with Net::HTTP
    end
  end
end
