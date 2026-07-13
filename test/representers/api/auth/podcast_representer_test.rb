require "test_helper"

describe Api::Auth::PodcastRepresenter do
  let(:podcast) { create(:podcast) }
  let(:representer) { Api::Auth::PodcastRepresenter.new(podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it "has a feeds property" do
    assert json.key?("feeds")
    assert_equal 1, json["feeds"].count
    assert_equal podcast.default_feed.id, json["feeds"][0]["id"]
    assert_equal "Default RSS Feed", json["feeds"][0]["label"]
    assert_equal false, json["feeds"][0]["private"]
    assert_nil json["feeds"][0]["slug"]
  end

  it "has authorized links" do
    assert_equal json["_links"]["self"]["href"], "/api/v1/authorization/podcasts/#{podcast.id}"
    assert_match("/api/v1/authorization/podcasts/#{podcast.id}/episodes", json["_links"]["prx:episodes"]["href"])
  end

  it "has an authorized feed" do
    assert_match("/api/v1/authorization/podcasts/#{podcast.id}/feeds", json["_links"]["prx:feeds"]["href"])
  end
end
