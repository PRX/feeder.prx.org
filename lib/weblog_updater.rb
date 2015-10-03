require 'xmlrpc/client'

class WeblogUpdater

  PING_FEEDBURNER_URL = 'http://ping.feedburner.com'

  def self.ping(options = {})
    new.ping(options)
  end

  def ping(options = {})
    feed_url = options[:feed_url]

    ping_url = options[:ping_url] || PING_FEEDBURNER_URL
    feed_name = options[:feed_name] || get_feed_name(feed_url)

    client = XMLRPC::Client.new2(ping_url)
    response = client.call('weblogUpdates.ping', feed_name, feed_url)

    # successful response {"flerror"=>false, "message"=>"Ok"}
    if response['flerror']
      raise "Ping failed: #{ping_url}, #{feed_url}, #{response['message']}"
    end
    response
  end

  def get_feed_name(url)
    url.split('/').last
  end
end
