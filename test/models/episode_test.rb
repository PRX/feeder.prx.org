require "test_helper"

describe Episode do
  let(:episode) { create(:episode_with_media) }

  it "initializes guid" do
    e = Episode.new
    refute_nil e.guid
  end

  it "sets updated_at when soft deleting episodes with no content" do
    minimal_episode = Episode.create!(podcast: episode.podcast, title: "title", updated_at: 1.day.ago)
    assert minimal_episode.updated_at < 10.minutes.ago

    minimal_episode.destroy!
    assert minimal_episode.updated_at > 10.minutes.ago
  end

  it "validates descriptions have a maximum of 4000 bytes" do
    e = build_stubbed(:episode, segment_count: 2, published_at: nil, strict_validations: true)

    e.description = nil
    assert e.valid?

    e.description = "a" * 4000
    assert e.valid?

    e.description = "a" * 4001
    refute e.valid?

    e.description = "a" * 3999 + "’"
    refute e.valid?

    e.strict_validations = false
    assert e.valid?
  end

  it "has a safe description for integrations" do
    e = build_stubbed(:episode, segment_count: 2, published_at: nil, strict_validations: true)
    e.description = "a" * 4001
    assert e.description.bytesize == 4001
    assert e.description_safe.bytesize == 4000
  end

  it "has a safe title for integrations" do
    e = build_stubbed(:episode, segment_count: 2, published_at: nil, strict_validations: true)
    e.title = "a" * 121
    assert e.title.bytesize == 121
    assert e.title_safe.bytesize == 120
  end

  it "handles blank title in title_safe" do
    e = build_stubbed(:episode, segment_count: 2, published_at: nil, strict_validations: true)
    e.title = nil
    assert_equal "", e.title_safe
  end

  it "has a description with fallbacks" do
    e = build_stubbed(:episode, segment_count: 2, published_at: nil, strict_validations: true)
    e.title = "title"
    e.subtitle = nil
    e.description = ""
    assert e.description_with_default == "title"
    e.subtitle = "sub"
    assert e.description_with_default == "sub"
    e.description = "desc"
    assert e.description_with_default == "desc"
  end

  it "validates unique original guids" do
    e1 = create(:episode, original_guid: "original")
    e2 = build(:episode, original_guid: "original", podcast: e1.podcast)
    assert e1.valid?
    refute e2.valid?
  end

  it "prevents trailing spaces on original guids" do
    e = create(:episode, original_guid: " original ")
    assert e.valid?
    assert e.original_guid = "original"
  end

  it "leaves title ampersands alone" do
    episode.title = "Hear & Now"
    episode.save!
    assert_equal episode.title, "Hear & Now"
  end

  it "validates titles have a maximum of 120 bytes" do
    e = build_stubbed(:episode, segment_count: 2, published_at: nil, strict_validations: true)

    e.title = "a" * 120
    assert e.valid?

    e.title = "a" * 121
    refute e.valid?

    e.title = "a" * 119 + "🎧" # 4 bytes
    refute e.valid?

    e.strict_validations = false
    assert e.valid?
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
    episode.podcast_id = 123

    assert_nil episode.original_guid
    assert_equal "prx_123_guid", episode.item_guid

    episode.item_guid = "changed"
    assert_equal "changed", episode.original_guid
    assert_equal "changed", episode.item_guid

    # setting to generated value nils it out
    episode.item_guid = "prx_123_guid"
    assert_nil episode.original_guid
    assert_equal "prx_123_guid", episode.item_guid

    # blanks also nil out
    episode.item_guid = ""
    assert_nil episode.original_guid
    assert_equal "prx_123_guid", episode.item_guid
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

  it "gets and sets url" do
    e = build_stubbed(:episode, url: nil)
    assert_includes e.url, "play.prx.org"
    assert_nil e[:url]

    e.url = "http://some.where/else"
    assert_equal "http://some.where/else", e[:url]

    e.url = "https://play.prx.org/any/thing"
    assert_nil e[:url]
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

  it "sanitizes categories" do
    e = build_stubbed(:episode)

    e.categories = []
    assert_equal [], e.categories
    assert_nil e[:categories]

    e.categories = ["foo", " Foo ", "BAR  ", "  fOO", "bar", "!@  $?"]
    assert_equal ["foo", "BAR", "!@  $?"], e.categories
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

  describe "#published_by" do
    it "checks for published episodes with offset" do
      e1 = create(:episode, published_at: 10.minutes.ago)
      e2 = create(:episode, published_at: 10.minutes.from_now)

      assert_equal [e1, e2].sort_by(&:id), Episode.published_by(-900).order(id: :asc)
      assert_equal [e1], Episode.published_by(-300)
      assert_equal [e1], Episode.published_by(0)
      assert_equal [e1], Episode.published_by(300)
      assert_empty Episode.published_by(900)
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

  describe "#description_with_default" do
    let(:episode) { build_stubbed(:episode, description: "description", subtitle: "subtitle", title: "title") }

    it "returns the description if present" do
      assert_equal "description", episode.description_with_default
    end

    it "returns the subtitle if description is blank" do
      episode.description = nil
      assert_equal "subtitle", episode.description_with_default
    end

    it "returns the title if description and subtitle are blank" do
      episode.description = nil
      episode.subtitle = nil
      assert_equal "title", episode.description_with_default
    end

    it "returns an empty string if description, subtitle, and title are blank" do
      episode.description = nil
      episode.subtitle = nil
      episode.title = nil
      assert_equal "", episode.description_with_default
    end
  end

  describe "#publish!" do
    let(:episode) { create(:episode) }
    let(:container) { create(:apple_podcast_container, episode: episode) }
    let(:delivery) { create(:apple_podcast_delivery, episode: episode, podcast_container: container) }

    before do
      assert_equal [delivery], episode.apple_podcast_deliveries
    end

    it "destroys any existing apple podcast deliveries" do
      refute_empty container.podcast_deliveries
      refute_empty episode.apple_podcast_deliveries
      episode.publish!
      assert episode.apple_status.present?
      assert episode.apple_status.delivered == false

      assert episode.apple_needs_delivery?
    end

    it "can be called for an episode without a container" do
      delivery.destroy!
      container.destroy!
      episode.reload

      assert_empty episode.apple_podcast_deliveries
      episode.publish!
      assert_empty episode.apple_podcast_deliveries
    end
  end

  describe "#ready_transcript" do
    let(:episode) { build_stubbed(:episode) }

    it "checks for a complete transcript" do
      assert_nil episode.ready_transcript

      episode.build_transcript(status: "processing")
      assert_nil episode.ready_transcript

      episode.transcript.status = "invalid"
      assert_nil episode.ready_transcript

      episode.transcript.status = "complete"
      refute_nil episode.ready_transcript
    end
  end

  describe "#head_request" do
    let(:episode_1) { build_stubbed(:episode) }
    let(:episode_2) { build_stubbed(:episode) }
    let(:episode_3) { build_stubbed(:episode) }

    it "returns response for a successful request" do
      uri_1 = episode_1.enclosure_url

      stub_request(:head, uri_1).to_return(status: 200)

      assert_kind_of Net::HTTPSuccess, episode_1.head_request
      assert_requested :head, episode_1.enclosure_url
    end

    it "handles redirects" do
      uri_1 = episode_1.enclosure_url
      uri_2 = episode_2.enclosure_url
      uri_3 = episode_3.enclosure_url

      stub_request(:head, uri_1).to_return(status: 302, headers: {location: uri_2})
      stub_request(:head, uri_2).to_return(status: 301, headers: {location: uri_3})
      stub_request(:head, uri_3).to_return(status: 200)

      episode_1.head_request

      assert_requested :head, episode_1.enclosure_url
      assert_requested :head, episode_2.enclosure_url
      assert_requested :head, episode_3.enclosure_url
    end

    it "does not follow more than 10 redirects" do
      uri_1 = episode_1.enclosure_url

      stub_request(:head, uri_1)
        .to_return(status: 302, headers: {location: uri_1}).times(50)

      episode_1.head_request

      assert_requested :head, episode_1.enclosure_url, times: 10
    end
  end
end
