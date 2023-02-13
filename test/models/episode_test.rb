require "test_helper"
require "prx_access"

describe Episode do
  include PrxAccess

  let(:episode) { create(:episode) }

  it "initializes guid and overrides" do
    e = Episode.new
    refute_nil e.guid
    refute_nil e.overrides
  end

  it "sets updated_at when soft deleting episodes with no content" do
    minimal_episode = Episode.create!(podcast: episode.podcast, title: "title", updated_at: 1.day.ago)
    assert minimal_episode.updated_at < 10.minutes.ago

    minimal_episode.destroy!
    assert minimal_episode.updated_at > 10.minutes.ago
  end

  it "validates unique original guids" do
    e1 = create(:episode, original_guid: "original")
    e2 = build(:episode, original_guid: "original", podcast: e1.podcast)
    assert e1.valid?
    refute e2.valid?
  end

  it "leaves title ampersands alone" do
    episode.title = "Hear & Now"
    episode.save!
    assert_equal episode.title, "Hear & Now"
  end

  it "must belong to a podcast" do
    episode = build_stubbed(:episode)
    assert episode.valid?
    assert_respond_to episode, :podcast

    episode = build_stubbed(:episode, podcast: nil)
    refute episode.valid?
  end

  it "lazily sets the guid" do
    episode = build(:episode, guid: nil)
    refute_nil episode.guid
  end

  it "returns a guid to use in the channel item" do
    episode.guid = "guid"
    assert_equal episode.item_guid, "prx_#{episode.podcast_id}_guid"
    assert_equal Episode.generate_item_guid(123, "abc"), "prx_123_abc"
  end

  it "decodes guids from channel item guids" do
    assert_equal Episode.decode_item_guid("prx_123_abc"), "abc"
    assert_equal Episode.decode_item_guid("prx_123_abc_def_ghi"), "abc_def_ghi"
    assert_nil Episode.decode_item_guid("anything")
  end

  it "finds episodes by item guid" do
    episode = create(:episode)
    generated_guid = "prx_#{episode.podcast_id}_#{episode.guid}"

    assert_nil episode.original_guid
    assert_equal episode.item_guid, generated_guid
    assert_equal Episode.find_by_item_guid(generated_guid), episode
    assert_nil Episode.find_by_item_guid("anything-else")

    episode.update!(original_guid: "something-original")
    assert_equal episode.item_guid, "something-original"
    assert_equal Episode.find_by_item_guid("something-original"), episode
    assert_nil Episode.find_by_item_guid(generated_guid)
  end

  it "is ready to add to a feed" do
    assert episode.include_in_feed?
  end

  it "knows if audio is ready" do
    episode.enclosures = [create(:enclosure, episode: episode)]
    assert_equal episode.enclosures.first.status, "created"
    refute episode.enclosures.first.complete?
    assert episode.media?
    refute episode.media_ready?
    assert_equal episode.media_status, "processing"
    episode.enclosures.first.complete!
    assert episode.enclosure.complete?
    assert episode.media?
    assert episode.media_ready?
    assert_equal episode.media_status, "complete"
  end

  it "returns an audio content_type by default" do
    assert_equal Episode.new.content_type, "audio/mpeg"
  end

  it "returns the first media content_type" do
    assert_equal episode.content_type, "audio/mpeg"
  end

  it "returns the feed content type for audio" do
    feed = build_stubbed(:feed)
    assert_equal feed.mime_type, "audio/flac"
    assert_equal episode.first_media_resource.mime_type, "audio/mpeg"
    assert_equal episode.content_type(feed), "audio/flac"
  end

  it "returns the file content type for video" do
    feed = build_stubbed(:feed)
    episode = build(:episode)
    video_enclosure = create(:enclosure, episode: episode, status: "complete", mime_type: "video/mp4")
    episode.enclosures = [video_enclosure]

    assert_equal video_enclosure.mime_type, "video/mp4"
    assert_equal episode.first_media_resource.mime_type, "video/mp4"
    assert_equal episode.content_type(feed), "video/mp4"
  end

  it "has no audio file until processed" do
    episode = build_stubbed(:episode)
    assert_equal episode.media_files.length, 0
  end

  it "has one audio file once processed" do
    episode = create(:episode)
    assert_equal episode.media_files.length, 1
  end

  it "has a 0 duration when unprocessed" do
    episode = build_stubbed(:episode)
    assert_equal episode.duration, 0
  end

  it "has duration once processed" do
    episode = create(:episode)
    episode.enclosures = [create(:enclosure, episode: episode, status: "complete", duration: 10)]
    assert_equal episode.duration, 10
  end

  it "has duration with podcast duration padding" do
    episode = create(:episode)
    episode.enclosures = [create(:enclosure, episode: episode, status: "complete", duration: 10)]
    episode.podcast.duration_padding = 10
    assert_equal episode.duration, 20
  end

  it "updates the podcast published date" do
    now = 1.minute.ago
    podcast = episode.podcast
    orig = episode.podcast.published_at
    refute_equal now, orig
    episode.run_callbacks :save do
      episode.update_attribute(:published_at, now)
    end
    assert_not_equal podcast.reload.published_at.to_i, orig.to_i
    assert_equal podcast.reload.published_at.to_i, now.to_i
  end

  it "sets one unique identifying episode keyword for tracking purposes" do
    orig_keyword = episode.keyword_xid
    episode.update(published_at: 1.day.from_now, title: "A different title")
    episode.run_callbacks :save do
      episode.save
    end
    refute_nil episode.reload.keyword_xid
    assert_equal episode.reload.keyword_xid, orig_keyword
  end

  it "strips non-alphanumeric characters from identifying keyword" do
    episode.update(keyword_xid: nil, title: "241: It's a TITLE, yAy!")
    episode.run_callbacks :save do
      episode.save
    end
    refute_nil episode.reload.keyword_xid
    assert_includes episode.keyword_xid, "241 its a title yay"
  end

  it "strips non-alphanumeric characters from all keywords" do
    episode.update(keywords: ["Here's John,ny!?"])
    episode.run_callbacks :save do
      episode.save
    end
    refute_nil episode.reload.keywords
    episode.keywords.each { |k| refute_match(/['?!,]/, k) }
  end

  it "has a valid itunes episode type" do
    assert_equal episode.itunes_type, "full"
    episode.itunes_type = "foo"
    refute episode.valid?
  end

  it "sets the itunes block to false by default" do
    refute episode.itunes_block
    episode.update_attribute(:itunes_block, true)
    assert episode.itunes_block
  end

  it "sets media files by adding new ones" do
    assert_equal episode.all_contents.count, 0

    episode.media_files = [build(:content, episode: episode)]
    assert_equal episode.all_contents.count, 1

    episode.media_files = [build(:content, episode: episode), build(:content, episode: episode)]
    assert_equal episode.all_contents.count, 3
  end

  it "deletes media files" do
    assert_equal episode.all_contents.count, 0

    episode.media_files = [build(:content, episode: episode), build(:content, episode: episode)]
    assert_equal episode.all_contents.count, 2

    episode.media_files = [build(:content, episode: episode)]
    assert_equal episode.all_contents.count, 2

    episode.media_files = []
    assert_equal episode.all_contents.count, 0
  end

  it "finds existing content based on the last 2 segments of the url" do
    episode.all_contents << build(:content, episode: episode, position: 1)
    assert_equal episode.all_contents.first.href, "s3://prx-testing/test/audio.mp3"

    refute_nil episode.find_existing_content(1, "s3://prx-testing/test/audio.mp3")
    refute_nil episode.find_existing_content(1, "s3://change-this/test/audio.mp3")
    refute_nil episode.find_existing_content(1, "http://prx-testing/any/thing/here/test/audio.mp3")

    assert_nil episode.find_existing_content(1, nil)
    assert_nil episode.find_existing_content(1, "s3://prx-testing/changed/audio.mp3")
    assert_nil episode.find_existing_content(1, "s3://prx-testing/test/changed.mp3")
    assert_nil episode.find_existing_content(2, "s3://prx-testing/test/audio.mp3")
  end

  it "returns explicit_content based on the podcast" do
    podcast = episode.podcast
    episode.explicit = nil

    ["explicit", "yes", true].each do |val|
      podcast.explicit = val
      assert_equal episode.explicit_content, true
    end

    ["clean", "no", false].each do |val|
      podcast.explicit = val
      assert_equal episode.explicit_content, false
    end
  end

  it "returns explicit_content overriden by the episode" do
    podcast = episode.podcast

    podcast.explicit = false
    ["explicit", "yes", true].each do |val|
      episode.explicit = val
      assert_equal episode.explicit_content, true
    end

    podcast.explicit = true
    ["clean", "no", false].each do |val|
      episode.explicit = val
      assert_equal episode.explicit_content, false
    end
  end

  describe "release episodes" do
    let(:podcast) { episode.podcast }

    before do
      day_ago = 1.day.ago
      podcast.update_columns(updated_at: day_ago)
      episode.update_columns(updated_at: day_ago, published_at: 1.hour.ago)
    end

    it "lists episodes to release" do
      assert_operator podcast.last_build_date, :<, episode.published_at
      episodes = Episode.episodes_to_release
      assert_equal episodes.size, 1
      assert_equal episodes.first, episode
    end

    it "updates feed published date after release" do
      assert_operator podcast.published_at, :<, episode.published_at
      episodes = Episode.episodes_to_release
      assert_equal episodes.first, episode
      Episode.release_episodes!
      podcast.reload
      assert_equal podcast.published_at.to_i, episode.published_at.to_i
    end
  end

  describe "prx story" do
    let(:story) do
      msg = json_file(:prx_story_small)
      body = JSON.parse(msg)
      href = body.dig(:_links, :self, :href)
      resource = PrxAccess::PrxHyperResource.new(root: "https://cms.prx.org/api/vi/")
      link = PrxAccess::PrxHyperResource::Link.new(resource, href: href)
      PrxAccess::PrxHyperResource.new_from(body: body, resource: resource, link: link)
    end

    it "can be found by story" do
      create(:episode, prx_uri: "/api/v1/stories/80548")
      episode = Episode.by_prx_story(story)
      refute_nil episode
    end
  end

  describe "#image" do
    it "replaces images" do
      refute_nil episode.image_file
      refute_nil episode.image
      refute_empty episode.images

      episode.image_file = {original_url: "test/fixtures/transistor1400.jpg"}
      episode.save!
      assert_equal episode.reload.images.count, 2
      assert_equal episode.image_file.original_url, "test/fixtures/transistor1400.jpg"
      assert_equal episode.image_file.status, "created"

      # image is still the completed one
      refute_equal episode.image, episode.image_file
      assert_equal episode.image.status, "complete"
    end

    it "ignores existing images" do
      assert_equal episode.images.count, 1

      episode.image_file = {original_url: episode.image.original_url}
      episode.image_file = episode.image.original_url
      episode.image_file = {original_url: episode.image.original_url}
      episode.save!
      assert_equal episode.images.count, 1
    end

    it "deletes images" do
      refute_empty episode.images

      episode.image_file = nil
      assert_empty episode.reload.images
    end
  end
end
