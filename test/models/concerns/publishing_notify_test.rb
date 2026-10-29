require "test_helper"

class PublishingStatusTest < ActiveSupport::TestCase
  include PublishingNotify

  let(:podcast) { create(:podcast) }
  let(:feed) { build(:feed, podcast: podcast, private: false) }
  let(:websub_url) { "https://pubsubhubbub.appspot.com/" }

  test "notify_rss_published sends Podping notification" do
    _(feed.public?).must_equal true
    podping_url = "https://podping.cloud/?url=#{CGI.escape(feed.url)}"
    stub_request(:post, websub_url)

    stub_request(:get, podping_url)
      .with(
        headers: {
          "Authorization" => "test_token",
          "User-Agent" => "PRX"
        }
      )
      .to_return(status: 200, body: "", headers: {})

    notify_rss_published(podcast, feed)
    assert_requested :get, podping_url
  end

  test "notify_podping filters the Authorization header from logs" do
    stub_request(:get, /podping.cloud/)
    log = StringIO.new

    Rails.stub(:logger, Logger.new(log)) do
      notify_podping(feed)
    end

    _(log.string).must_include "Authorization: \"[FILTERED]\""
    _(log.string).wont_include "test_token"
  end

  test "notify_rss_published sends WebSub notification" do
    stub_request(:get, /podping.cloud/)
    websub = stub_request(:post, websub_url)
      .with(
        body: {"hub.mode" => "publish", "hub.url" => feed.url},
        headers: {"Content-Type" => "application/x-www-form-urlencoded"}
      )
      .to_return(status: 204)

    notify_rss_published(podcast, feed)
    assert_requested websub
  end

  test "notify_rss_published sends WebSub notification when Podping fails" do
    stub_request(:get, /podping.cloud/).to_return(status: 500)
    stub_request(:post, websub_url).to_return(status: 204)

    notify_rss_published(podcast, feed)
    assert_requested :post, websub_url
  end

  test "notify_rss_published does not send WebSub notification for private feeds" do
    stub_request(:post, websub_url)

    feed.private = true
    notify_rss_published(podcast, feed)
    assert_requested :post, websub_url, times: 0
  end

  test "notify_rss_published handles a feed with a null url" do
    stub_request(:get, "https://podping.cloud/?url")
      .to_return(status: 200, body: "", headers: {})
    stub_request(:post, websub_url)

    feed.url = nil
    notify_rss_published(podcast, feed)
    assert_requested :get, "https://podping.cloud/?url", times: 0
    assert_requested :post, websub_url, times: 0
  end
end
