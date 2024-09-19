require "test_helper"

describe Api::PodcastRepresenter do
  let(:podcast) { create(:podcast) }
  let(:representer) { Api::PodcastRepresenter.new(podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it "includes basic properties" do
    assert_equal json["path"], podcast.path
    assert_match(/\/api\/v1\/series\//, json["prxUri"])
  end

  it "includes itunes categories" do
    refute_nil json["itunesCategories"]
    assert_equal json["itunesCategories"].first["name"], "Leisure"
  end

  it "includes owner" do
    assert_equal json["owner"]["name"], "Jesse Thorn"
    assert_equal json["owner"]["email"], "jesse@maximumfun.org"
  end

  it "includes categories" do
    assert_includes json["categories"], "Humor"
  end

  it "includes itunes image" do
    assert_equal json["itunesImage"]["href"], "http://some.where/test/fixtures/valid_series_image.jpg"
  end

  it "includes feed image" do
    assert_equal json["feedImage"]["href"], "http://some.where/test/fixtures/valid_feed_image.png"
  end

  it "includes serial v. episodic ordering" do
    assert_equal json["serialOrder"], false
  end

  it "includes itunes block" do
    assert_equal json["itunesBlock"], false
  end

  it "has links" do
    assert_equal json["_links"]["self"]["href"], "/api/v1/podcasts/#{podcast.id}"
    assert_equal json["_links"]["prx:account"]["href"], "https://id.prx.org#{podcast.prx_account_uri}"
  end
end
