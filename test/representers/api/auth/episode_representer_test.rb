require "test_helper"

describe Api::Auth::EpisodeRepresenter do
  let(:episode) { create(:episode_with_media) }
  let(:c1) { episode.contents.first }
  let(:representer) { Api::Auth::EpisodeRepresenter.new(episode) }
  let(:json) { JSON.parse(representer.to_json) }

  it "has authorized links" do
    assert_equal json["_links"]["self"]["href"], "/api/v1/authorization/episodes/#{episode.guid}"
  end

  it "has media with href" do
    assert_equal 1, json["media"].size
    assert_equal c1.url, json["media"].first["href"]
    assert_equal c1.original_url, json["media"].first["originalUrl"]
    assert_equal c1.file_name, json["media"].first["fileName"]

    # media is ready, so there's no readyMedia
    assert_nil json["readyMedia"]
  end

  it "has ready media when media is not complete" do
    refute_empty episode.complete_media
    refute_empty episode.media_versions

    # replace with an incomplete segment
    assert c1.persisted?
    c2 = create(:content, episode: episode, status: "created")
    episode.reload

    # c2 is the latest enclosure, but incomplete (href is original_url)
    assert_equal 1, json["media"].size
    assert_equal c2.original_url, json["media"].first["href"]
    assert_equal c2.original_url, json["media"].first["originalUrl"]
    assert_equal "created", json["media"].first["status"]

    assert_equal 1, json["readyMedia"].size
    assert_equal c1.url, json["readyMedia"].first["href"]
    assert_equal c1.original_url, json["readyMedia"].first["originalUrl"]
    assert_equal "complete", json["readyMedia"].first["status"]
  end
end
