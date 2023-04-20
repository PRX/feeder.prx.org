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

  it "includes items in feed" do
    episode = create(:episode, segment_count: nil, contents: [], enclosures: [])
    episode.enclosures.destroy_all
    assert episode.include_in_feed?

    episode.update(segment_count: 1)
    refute episode.reload.include_in_feed?

    content = create(:content, episode: episode, status: "processing")
    refute episode.reload.include_in_feed?

    content.update(status: "complete")
    assert episode.reload.include_in_feed?
  end

  it "knows if enclosure audio is ready" do
    e1 = episode.enclosures.first
    assert_equal "complete", e1.status
    assert_equal [e1], episode.media_resources
    assert_equal [e1], episode.ready_media_resources
    assert episode.media_ready?

    # replace with an incomplete enclosure
    e2 = create(:enclosure, episode: episode)
    assert_equal "created", episode.enclosures.first.status
    assert_equal [e2], episode.media_resources
    assert_equal [e1], episode.ready_media_resources
    assert episode.media_ready?

    # set first (replaced) enclosure back to processing
    e1.update(status: "processing")
    assert_equal [e2], episode.media_resources
    assert_equal [], episode.ready_media_resources
    refute episode.media_ready?
  end

  it "knows if contents audio is ready" do
    c1 = create(:content, episode: episode, status: "complete", position: 1)
    assert_equal [c1], episode.media_resources
    assert_equal [c1], episode.ready_media_resources
    assert episode.media_ready?

    # explicit segment_count
    episode.update(segment_count: 2)
    assert_equal [c1], episode.media_resources
    assert_equal [c1], episode.ready_media_resources
    refute episode.media_ready?

    # with all positions complete
    c2 = create(:content, episode: episode, status: "complete", position: 2)
    assert_equal [c1, c2], episode.media_resources.reload
    assert_equal [c1, c2], episode.ready_media_resources
    assert episode.media_ready?

    # replace with an incomplete content
    c3 = create(:content, episode: episode, status: "processing", position: 1)
    assert_equal [c3, c2], episode.media_resources.reload
    assert_equal [c1, c2], episode.ready_media_resources
    assert episode.media_ready?
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
    assert_equal episode.media_resources.length, 0
  end

  it "has one audio file once processed" do
    episode = create(:episode)
    assert_equal episode.media_resources.length, 1
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

  it "sets contents by adding new ones" do
    assert_equal episode.contents.count, 0

    c1 = build(:content, episode: episode)
    episode.update!(contents: [c1])
    assert_equal episode.contents.count, 1

    c2 = build(:content, episode: episode)
    episode.update!(contents: [c1.original_url, c2])
    assert_equal episode.contents.count, 2
    assert_equal episode.contents.with_deleted.count, 2
  end

  it "deletes media files" do
    assert_equal episode.contents.count, 0

    c1 = build(:content, episode: episode)
    c2 = build(:content, episode: episode)
    episode.update!(contents: [c1, c2])
    assert_equal episode.contents.count, 2
    assert_equal episode.contents.with_deleted.count, 2

    episode.update!(contents: [c1])
    assert_equal episode.contents.count, 1
    assert_equal episode.contents.with_deleted.count, 2

    episode.update!(contents: nil)
    assert_equal episode.contents.count, 0
    assert_equal episode.contents.with_deleted.count, 2
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
      refute_nil episode.image
      refute_empty episode.images

      episode.image = {original_url: "test/fixtures/transistor1400.jpg"}
      episode.save!
      assert_equal episode.reload.images.with_deleted.count, 2
      assert_equal episode.reload.images.count, 1
      assert_equal episode.image.original_url, "test/fixtures/transistor1400.jpg"
      assert_equal episode.image.status, "created"

      # ready_image is still the completed one
      refute_equal episode.ready_image, episode.image
      assert_equal episode.ready_image.status, "complete"
      refute_nil episode.ready_image.deleted_at
      refute_nil episode.ready_image.replaced_at
    end

    it "ignores existing images" do
      assert_equal episode.images.count, 1

      episode.image = {original_url: episode.image.original_url}
      episode.image = episode.image.original_url
      episode.image = {original_url: episode.image.original_url}
      episode.save!
      assert_equal episode.images.with_deleted.count, 1
    end

    it "deletes images" do
      refute_empty episode.images

      episode.update(image: nil)
      assert_empty episode.reload.images

      assert_nil episode.ready_image
      assert_nil episode.images.with_deleted.first.replaced_at
    end
  end

  describe "#segment_range" do
    it "returns a range of positions" do
      e = Episode.new(segment_count: nil)
      assert_equal [], e.segment_range.to_a

      e.segment_count = 1
      assert_equal [1], e.segment_range.to_a

      e.segment_count = 4
      assert_equal [1, 2, 3, 4], e.segment_range.to_a
    end
  end

  describe "#build_contents" do
    it "builds contents for missing positions" do
      e = Episode.new(segment_count: 3)
      c1 = e.contents.build(position: 2)
      _c2 = e.contents.build(position: 4)

      built = e.build_contents
      assert_equal 3, built.length
      assert_equal 1, built[0].position
      assert_equal c1, built[1]
      assert_equal 3, built[2].position
    end
  end

  describe "#destroy_out_of_range_contents" do
    it "marks contents for destruction" do
      c1 = episode.contents.create!(position: 2)
      c2 = episode.contents.create!(position: 4)

      episode.segment_count = nil
      episode.destroy_out_of_range_contents
      assert_nil c1.reload.deleted_at
      assert_nil c2.reload.deleted_at

      episode.segment_count = 3
      episode.destroy_out_of_range_contents
      assert_nil c1.reload.deleted_at
      refute_nil c2.reload.deleted_at
    end
  end
end
