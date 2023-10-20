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
  end

  describe "#published_url" do
    it "returns default feed path" do
      assert_equal feed1.published_path, "feed-rss.xml"
      assert_equal feed2.published_path, "adfree/feed-rss.xml"
      assert_equal feed3.published_path, "other/something"
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

  describe "#filtered_episodes" do
    let(:ep) { create(:episode, podcast: feed1.podcast) }

    it "should include episodes based on a tag" do
      feed1.update!(include_tags: ["foo"])

      assert_equal feed1.reload.filtered_episodes, []
      ep.update!(categories: ["foo"])
      assert_equal feed1.reload.filtered_episodes, [ep]
    end

    it "should exclude episodes based on a tag" do
      feed1.update!(exclude_tags: ["foo"])

      ep = create(:episode, podcast: feed1.podcast)

      # Add the episode category so we can match the feed "exclude_tags"
      # Using the same tag based include scheme.
      assert_equal feed1.reload.filtered_episodes, [ep]
      ep.update!(categories: ["foo"])
      assert_equal feed1.reload.filtered_episodes, []
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

  describe "#filtered_episodes" do
    let(:ep) { create(:episode, podcast: feed1.podcast) }

    it "should include episodes based on a tag" do
      feed1.update!(include_tags: ["foo"])

      assert_equal feed1.reload.filtered_episodes, []
      ep.update!(categories: ["foo"])
      assert_equal feed1.reload.filtered_episodes, [ep]
    end

    it "should exclude episodes based on a tag" do
      feed1.update!(exclude_tags: ["foo"])

      ep = create(:episode, podcast: feed1.podcast)

      # Add the episode category so we can match the feed "exclude_tags"
      # Using the same tag based include scheme.
      assert_equal feed1.reload.filtered_episodes, [ep]
      ep.update!(categories: ["foo"])
      assert_equal feed1.reload.filtered_episodes, []
    end
  end

  describe "#apple_configs" do
    it "has apple credentials" do
      creds = create(:apple_config, public_feed: feed1, private_feed: feed2)
      assert_equal feed1.apple_configs, [creds]
      assert_equal feed1.apple_configs.first.private_feed, feed2
    end
  end

  describe "#publish_to_apple?" do
    it "returns true if the feed has apple credentials" do
      creds = create(:apple_config, public_feed: feed1, private_feed: feed2, publish_enabled: true)
      assert feed1.publish_to_apple?(creds)
      refute feed2.publish_to_apple?(creds)
    end

    it "returns false if the creds are not marked publish_enabled?" do
      creds = create(:apple_config, public_feed: feed1, private_feed: feed2, publish_enabled: false)
      refute feed1.publish_to_apple?(creds)
    end

    it "returns false if the feed does not have apple credentials" do
      refute feed1.publish_to_apple?(create(:apple_config, public_feed: create(:feed), private_feed: create(:feed)))
    end
  end

  describe "#itunes_category" do
    it "is required for default feeds" do
      assert_equal 1, feed1.itunes_categories.count
      assert_equal "Leisure", feed1.itunes_category
      assert_equal "Aviation", feed1.itunes_subcategory

      feed1.itunes_category = nil
      assert feed1.invalid?
      assert_match(/can't be blank/i, feed1.errors.full_messages_for("itunes_categories.name").join)
    end

    it "can be deleted for non-default feeds" do
      create(:itunes_category, feed: feed2)

      assert_equal 1, feed2.itunes_categories.count
      assert_equal "Leisure", feed2.itunes_category
      assert_equal "Aviation", feed2.itunes_subcategory

      feed2.itunes_category = nil
      assert feed2.valid?
      assert feed2.itunes_categories[0].marked_for_destruction?
    end
  end
end
