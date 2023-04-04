require "test_helper"

describe Api::EpisodeRepresenter do
  let(:episode) { create(:episode) }
  let(:representer) { Api::EpisodeRepresenter.new(episode) }
  let(:json) { JSON.parse(representer.to_json) }

  it "includes basic properties" do
    assert_match(%r{/api/v1/stories/}, json["prxUri"])
    assert_match(%r{<a href="/tina">Tina</a>}, json["summary"])
  end

  it "includes clean title, season, episode, and ep type info" do
    assert_instance_of Integer, json["seasonNumber"]
    assert_instance_of Integer, json["episodeNumber"]
    assert_match(/Clean title/, json["cleanTitle"])
    assert_equal json["itunesType"], "full"
    assert_equal json["itunesBlock"], false
  end

  it "indicates if the episode media is not ready" do
    assert_equal json["isFeedReady"], true
  end

  it "includes an explicit_content value from the podcast" do
    assert_nil episode.explicit
    assert episode.podcast.explicit
    assert_equal json["explicitContent"], true
  end

  it "indicates if the episode media is not ready" do
    episode.enclosure.update(status: "error")
    assert_equal json["isFeedReady"], false
  end

  it "uses summary when not blank" do
    episode.summary = 'summary has <a href="/">a link</a>'
    episode.description = '<b>tags</b> removed, <a href="/">links remain</a>'
    assert_equal json["summary"], episode.summary
    assert_nil json["summaryPreview"]
    assert_equal json["description"], episode.description
  end

  it "uses sanitized description for nil summary" do
    episode.summary = nil
    episode.description = '<b>tags</b> removed, <a href="/">links remain</a>'
    assert_nil json["summary"]
    assert_equal json["summaryPreview"],
      'tags removed, <a href="/">links remain</a>'
    assert_equal json["description"], episode.description
  end

  it "has links" do
    assert_equal json["_links"]["self"]["href"],
      "/api/v1/episodes/#{episode.guid}"
    assert_equal json["_links"]["prx:podcast"]["href"],
      "/api/v1/podcasts/#{episode.podcast.id}"
    assert_equal json["_links"]["prx:story"]["href"],
      "https://cms.prx.org#{episode.prx_uri}"
    assert_equal json["_links"]["prx:audio-version"]["href"],
      "https://cms.prx.org#{episode.prx_audio_version_uri}"
  end

  it "has media" do
    assert_equal json["media"].size, 1
    assert_equal json["media"].first["href"], episode.enclosure.url
    assert_equal json["media"].first["originalUrl"], episode.enclosure.original_url

    # media is ready, so there's no readyMedia
    assert_nil json["readyMedia"]
  end

  it "has ready media when media is not complete" do
    e1 = episode.enclosure
    e2 = create(:enclosure, episode: episode, status: "created")

    # e2 is the latest enclosure, but incomplete (href is original_url)
    assert_equal json["media"].size, 1
    assert_equal json["media"].first["href"], e2.original_url
    assert_equal json["media"].first["originalUrl"], e2.original_url
    assert_equal json["media"].first["status"], "created"

    assert_equal json["readyMedia"].size, 1
    assert_equal json["readyMedia"].first["href"], e1.url
    assert_equal json["readyMedia"].first["originalUrl"], e1.original_url
    assert_equal json["readyMedia"].first["status"], "complete"
  end

  it "has an audio version" do
    assert_equal json["audioVersion"], "One segment audio"
    assert_equal json["segmentCount"], 1
  end

  it "has image" do
    assert_equal json["image"]["url"], episode.image.url
    assert_equal json["image"]["originalUrl"], episode.image.original_url
  end

  it "has enclosure" do
    assert_equal json["_links"]["enclosure"]["href"], episode.enclosure_url
  end

  it "has a podcast-feed" do
    assert_equal json["_links"]["prx:podcast-feed"]["href"],
      episode.podcast_feed_url
    assert_equal json["_links"]["prx:podcast-feed"]["type"],
      "application/rss+xml"
    assert_equal json["_links"]["prx:podcast-feed"]["title"],
      episode.podcast.title
  end

  it "has a default podcast-feed link when no podcast url set" do
    episode.podcast.url = nil
    assert_equal json["_links"]["prx:podcast-feed"]["href"],
      episode.podcast.published_url
  end

  it "can represent a sad, podcast-less episode" do
    episode.podcast_id = nil
    episode.podcast = nil
    json2 = JSON.parse(Api::EpisodeRepresenter.new(episode).to_json)
    assert_equal json2["guid"], "prx__#{episode.guid}"
    assert_nil json2["_links"]["enclosure"]
    assert_nil json2["_links"]["prx:podcast"]
    assert_nil json2["_links"]["prx:podcast-feed"]
  end
end
