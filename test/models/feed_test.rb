require "test_helper"

describe Feed do
  let(:podcast) { create(:podcast) }
  let(:feed1) { podcast.default_feed }
  let(:feed2) { create(:feed, private: false, podcast: podcast, slug: "adfree") }
  let(:feed3) { create(:feed, private: false, podcast: podcast, slug: "other", file_name: "something") }

  describe ".new" do
    it "sets a default file name" do
      assert_equal Feed.new.file_name, "feed-rss.xml"
    end
  end

  describe "mime type" do
    it "has a default mime type" do
      assert_equal Feed.new.mime_type, "audio/mpeg"
    end

    it "has a different mime type" do
      f = Feed.new(audio_format: {f: "flac", b: 16, c: 2, s: 44100})
      assert_equal f.mime_type, "audio/flac"
    end
  end

  describe "copy_media" do
    it "removes old s3 files" do
      removed_key = nil

      UnlinkJob.stub(:perform_later, ->(key) { removed_key = key }) do
        feed2.copy_media
        feed2.reload.copy_media
        assert_nil removed_key

        feed2.reload.update(slug: "change-it")
        feed2.copy_media
        assert_equal "#{podcast.path}/adfree/feed-rss.xml", removed_key

        feed2.reload.update(file_name: "change-it")
        feed2.copy_media
        assert_equal "#{podcast.path}/change-it/feed-rss.xml", removed_key
      end
    end
  end

  describe "#set_public_feeds_url" do
    let(:podcast) { build_stubbed(:podcast, path: nil) }
    let(:feed) { build_stubbed(:feed, podcast: podcast, private: false, url: nil) }
    let(:prefix) { "https://publicfeeds.net/f/#{podcast.id}" }

    it "sets a default public feeds url" do
      feed.set_public_feeds_url
      assert_equal "#{prefix}/#{feed.slug}/feed-rss.xml", feed.url

      feed.slug = nil
      feed.set_public_feeds_url
      assert_equal "#{prefix}/feed-rss.xml", feed.url

      feed.file_name = "blah.xml"
      feed.set_public_feeds_url
      assert_equal "#{prefix}/blah.xml", feed.url
    end

    it "does not overwrite non-blank urls" do
      feed.url = "https://some.where/feed.xml"
      feed.set_public_feeds_url
      assert_equal "https://some.where/feed.xml", feed.url
    end

    it "removes public feed urls from private feeds" do
      feed.url = "https://some.where/feed.xml"
      feed.private = true
      feed.set_public_feeds_url
      assert_nil feed.url
    end

    it "does nothing if ENV is blank" do
      old_prefix, ENV["PUBLIC_FEEDS_URL_PREFIX"] = ENV["PUBLIC_FEEDS_URL_PREFIX"], ""
      feed.set_public_feeds_url
      assert_nil feed.url
      ENV["PUBLIC_FEEDS_URL_PREFIX"] = old_prefix
    end
  end

  describe "#check_enclosure_changes" do
    let(:feed) { create(:feed) }

    it "sets a timestamp when the prefix changes" do
      feed = create(:feed)
      assert_nil feed.enclosure_updated_at

      feed.update(enclosure_prefix: "http://foo.bar")
      refute_nil feed.enclosure_updated_at
    end

    it "sets a timestamp when the template changes" do
      feed = create(:feed)
      assert_nil feed.enclosure_updated_at

      feed.update(enclosure_template: "http://foo.bar")
      refute_nil feed.enclosure_updated_at
    end
  end

  describe "#set_default_episodes" do
    it "adds default_feed.episodes to newly created feeds" do
      e1 = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      e2 = create(:episode, podcast: podcast, published_at: 1.minute.ago)

      # new episodes are added to default feeds
      assert_equal feed1.episode_ids, [e2.id, e1.id]
      feed1.episodes.destroy(e2)
      assert_equal feed1.episode_ids, [e1.id]

      # new feeds copy the default feed episodes
      new_feed = create(:feed, podcast: podcast)
      assert_equal new_feed.episode_ids, [e1.id]
    end
  end

  describe "#feed_episodes" do
    it "applies episode publish offsets and limits" do
      e1 = create(:episode, podcast: podcast, published_at: 1.day.ago)
      e2 = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      e3 = create(:episode, podcast: podcast, published_at: 1.minute.ago)
      e4 = create(:episode, podcast: podcast, published_at: 1.minute.from_now)

      assert_equal feed1.episode_ids, [e4.id, e3.id, e2.id, e1.id]
      assert_equal feed1.feed_episode_ids, [e3.id, e2.id, e1.id]

      feed1.episode_offset_seconds = -3600
      assert_equal feed1.feed_episode_ids, [e4.id, e3.id, e2.id, e1.id]

      feed1.display_episodes_count = 2
      assert_equal feed1.feed_episode_ids, [e4.id, e3.id]
    end
  end

  describe "#default" do
    it "returns default feeds" do
      assert feed1.default?
      refute feed2.default?
      refute feed3.default?
      assert podcast.feeds.count == 3
      assert_equal Feed.default.pluck(:id), [feed1.id]
    end
  end

  describe "#valid?" do
    it "validates unique slugs" do
      assert feed2.valid?
      assert feed3.valid?

      feed3.slug = "adfree"
      refute feed3.valid?

      feed3.slug = "adfree2"
      assert feed3.valid?
    end

    it "only allows 1 default feed per podcast" do
      assert feed1.valid?
      assert feed2.valid?

      feed2.slug = nil
      assert feed2.default?
      refute feed2.valid?

      feed2.podcast_id = 999999
      assert feed2.default?
      assert feed2.valid?
    end

    it "restricts slug characters" do
      ["", "n@-ats", "no/slash", "nospace ", "no.dots"].each do |s|
        feed1.slug = s
        refute feed1.valid?
      end
    end

    it "restricts some slugs already used in S3" do
      assert feed1.valid?

      feed1.slug = "default"
      refute feed1.valid?

      feed1.slug = "images"
      refute feed1.valid?

      feed1.slug = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
      refute feed1.valid?
    end

    it "restricts file name characters" do
      ["", "n@-ats", "no/slash", "nospace "].each do |s|
        feed1.file_name = s
        refute feed1.valid?
      end
    end

    it "has a default enclosure template" do
      feed = Podcast.new.tap { |p| p.valid? }
      assert_match(/^http/, Feed.enclosure_template_default)
      assert_equal feed.enclosure_template, Feed.enclosure_template_default
    end

    it "has a title if it is not default" do
      feed2.title = nil
      refute feed2.valid?
      feed2.title = "new feed"
      assert feed2.valid?
    end

    it "does not allow episode offsets on default" do
      feed1.episode_offset_seconds = 5
      assert feed1.default?
      assert feed1.invalid?

      feed1.episode_offset_seconds = 0
      assert feed1.valid?

      feed1.episode_offset_seconds = nil
      assert feed1.valid?

      # non-default feeds can have offsets
      feed2.episode_offset_seconds = 5
      assert feed2.valid?
    end
  end

  describe "#published_url" do
    it "returns feed paths" do
      assert_equal feed1.path_suffix, "feed-rss.xml"
      assert_equal feed2.path_suffix, "adfree/feed-rss.xml"
      assert_equal feed3.path_suffix, "other/something"

      assert_equal feed1.path, "#{podcast.path}/feed-rss.xml"
      assert_equal feed2.path, "#{podcast.path}/adfree/feed-rss.xml"
      assert_equal feed3.path, "#{podcast.path}/other/something"
    end

    it "returns default feed urls" do
      assert_equal feed1.published_url, "#{podcast.base_published_url}/feed-rss.xml"
    end

    it "returns slugged feed urls" do
      assert_equal feed2.published_url, "#{podcast.base_published_url}/adfree/feed-rss.xml"
      assert_equal feed3.published_url, "#{podcast.base_published_url}/other/something"
    end

    it "returns templated private feed urls" do
      feed1.private = true
      feed2.private = true
      feed3.private = true

      assert_equal feed1.published_url, "#{podcast.base_private_url}/feed-rss.xml{?auth}"
      assert_equal feed2.published_url, "#{podcast.base_private_url}/adfree/feed-rss.xml{?auth}"
      assert_equal feed3.published_url, "#{podcast.base_private_url}/other/something{?auth}"
    end
  end

  describe "#feed_image" do
    it "replaces images" do
      refute_nil feed1.feed_image
      refute_empty feed1.feed_images

      feed1.feed_image = "test/fixtures/transistor300.png"
      feed1.save!
      assert_equal feed1.reload.feed_images.with_deleted.count, 2
      assert_equal feed1.feed_images.count, 1
      assert_equal feed1.feed_image.original_url, "test/fixtures/transistor300.png"
      assert_equal feed1.feed_image.status, "created"

      # ready_feed_image is still the completed one
      refute_equal feed1.ready_feed_image, feed1.feed_image
      assert_equal feed1.ready_feed_image.status, "complete"
      refute_nil feed1.ready_feed_image.deleted_at
      refute_nil feed1.ready_feed_image.replaced_at
    end

    it "ignores existing images" do
      feed2.feed_image = {original_url: "test/fixtures/transistor300.png"}
      feed2.save!
      assert_equal feed2.feed_images.with_deleted.count, 1
      assert_equal feed2.feed_image.original_url, "test/fixtures/transistor300.png"
      assert_equal feed2.feed_image.status, "created"
      assert_nil feed2.reload.ready_feed_image

      feed2.feed_image = {original_url: "test/fixtures/transistor300.png"}
      feed2.feed_image = {original_url: "test/fixtures/transistor300.png"}
      feed2.feed_image = {original_url: "test/fixtures/transistor300.png"}
      feed2.save!
      assert_equal feed2.feed_images.with_deleted.count, 1
    end

    it "deletes images" do
      refute_empty feed1.feed_images

      feed1.update(feed_image: nil)
      assert_empty feed1.reload.feed_images

      assert_nil feed1.ready_feed_image
      assert_nil feed1.feed_images.with_deleted.first.replaced_at
    end
  end

  describe "#itunes_image" do
    it "replaces images" do
      refute_nil feed1.itunes_image
      refute_empty feed1.itunes_images

      feed1.itunes_image = "test/fixtures/transistor1400.jpg"
      feed1.save!
      assert_equal feed1.reload.itunes_images.with_deleted.count, 2
      assert_equal feed1.reload.itunes_images.count, 1
      assert_equal feed1.itunes_image.original_url, "test/fixtures/transistor1400.jpg"
      assert_equal feed1.itunes_image.status, "created"

      # ready_itunes_image is still the completed one
      refute_equal feed1.ready_itunes_image, feed1.itunes_image
      assert_equal feed1.ready_itunes_image.status, "complete"
      refute_nil feed1.ready_itunes_image.deleted_at
      refute_nil feed1.ready_itunes_image.replaced_at
    end

    it "ignores existing images" do
      feed2.itunes_image = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.save!
      assert_equal feed2.itunes_images.with_deleted.count, 1
      assert_equal feed2.itunes_image.original_url, "test/fixtures/transistor1400.jpg"
      assert_equal feed2.itunes_image.status, "created"
      assert_nil feed2.reload.ready_itunes_image

      feed2.itunes_image = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.itunes_image = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.itunes_image = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.save!
      assert_equal feed2.itunes_images.with_deleted.count, 1
    end

    it "deletes images" do
      refute_empty feed1.itunes_images

      feed1.update(itunes_image: nil)
      assert_empty feed1.reload.itunes_images

      assert_nil feed1.ready_itunes_image
      assert_nil feed1.itunes_images.with_deleted.first.replaced_at
    end
  end

  describe "#publish_to_apple?" do
    it "returns false if the feed is not an Apple Subscription feed" do
      refute_equal feed2.type, "Feeds::AppleSubscription"
      refute feed2.publish_to_apple?
    end
  end
end
