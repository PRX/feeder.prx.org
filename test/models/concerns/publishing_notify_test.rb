require "test_helper"

class PublishingStatusTest < ActiveSupport::TestCase
  include PublishingNotify

  let(:podcast) { create(:podcast) }
  let(:feed) { build(:feed, podcast: podcast, private: false) }

  test "notify_rss_published sends Podping notification" do
    _(feed.public?).must_equal true
    podping_url = "https://podping.cloud/?url=#{CGI.escape(feed.url)}"

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

  test "notify_rss_published handles a feed with a null url" do
    stub_request(:get, "https://podping.cloud/?url")
      .to_return(status: 200, body: "", headers: {})

    feed.url = nil
    notify_rss_published(podcast, feed)
    assert_requested :get, "https://podping.cloud/?url", times: 0
  end
end
