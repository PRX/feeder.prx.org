require "test_helper"

class PublishingStatusTest < ActiveSupport::TestCase
  include PublishingNotify

  let(:podcast) { create(:podcast) }
  let(:feed) { build(:feed, podcast: podcast, private: false) }

  test "notify_rss_published sends Podping notification" do
    _(feed.public?).must_equal true
    podping_url = "https://podping.cloud/?url=#{CGI.escape(feed.published_public_url)}"

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
end
