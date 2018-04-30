require 'test_helper'
require 'weblog_pinger'

describe WeblogPinger do

  let (:response_ok) {
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<methodResponse><params><param><value><struct>' +
      '<member><name>flerror</name><value><boolean>0</boolean></value></member>' +
      '<member><name>message</name><value>Ok</value></member>' +
    '</struct></value></param></params></methodResponse>'
  }

  before do
    stub_request(:post, 'http://ping.feedburner.com/').
      to_return(status: 200, body: response_ok, headers: {})
  end

  it 'successfully pings feedburner' do
    WeblogPinger.ping(feed_url: 'http://feeds.feedburner.com/tedtalks_audio')
  end

  describe 'failures' do
    it 'ping returns a 500 error' do
      stub_request(:post, 'http://ping.feedburner.com/').
        to_return(status: 500, body: '', headers: {})

      WeblogPinger.ping(feed_url: 'http://feeds.feedburner.com/tedtalks_audio')
    end
  end
end
