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

  describe "#feed_image_file" do
    it "replaces images" do
      refute_nil feed1.feed_image_file
      refute_nil feed1.feed_image
      refute_empty feed1.feed_images

      feed1.feed_image_file = "test/fixtures/transistor300.png"
      feed1.save!
      assert_equal feed1.reload.feed_images.count, 2
      assert_equal feed1.feed_image_file.original_url, "test/fixtures/transistor300.png"
      assert_equal feed1.feed_image_file.status, "created"

      # feed_image is still the completed one
      refute_equal feed1.feed_image, feed1.feed_image_file
      assert_equal feed1.feed_image.status, "complete"
    end

    it "ignores existing images" do
      feed2.feed_image_file = {original_url: "test/fixtures/transistor300.png"}
      feed2.save!
      assert_equal feed2.feed_images.count, 1
      assert_equal feed2.feed_image_file.original_url, "test/fixtures/transistor300.png"
      assert_equal feed2.feed_image_file.status, "created"
      assert_nil feed2.reload.feed_image

      feed2.feed_image_file = {original_url: "test/fixtures/transistor300.png"}
      feed2.feed_image_file = {original_url: "test/fixtures/transistor300.png"}
      feed2.feed_image_file = {original_url: "test/fixtures/transistor300.png"}
      feed2.save!
      assert_equal feed2.feed_images.count, 1
    end

    it "deletes images" do
      refute_empty feed1.feed_images

      feed1.feed_image_file = nil
      assert_empty feed1.reload.feed_images
    end
  end

  describe "#itunes_image_file" do
    it "replaces images" do
      refute_nil feed1.itunes_image_file
      refute_nil feed1.itunes_image
      refute_empty feed1.itunes_images

      feed1.itunes_image_file = "test/fixtures/transistor1400.jpg"
      feed1.save!
      assert_equal feed1.reload.itunes_images.count, 2
      assert_equal feed1.itunes_image_file.original_url, "test/fixtures/transistor1400.jpg"
      assert_equal feed1.itunes_image_file.status, "created"

      # itunes_image is still the completed one
      refute_equal feed1.itunes_image, feed1.itunes_image_file
      assert_equal feed1.itunes_image.status, "complete"
    end

    it "ignores existing images" do
      feed2.itunes_image_file = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.save!
      assert_equal feed2.itunes_images.count, 1
      assert_equal feed2.itunes_image_file.original_url, "test/fixtures/transistor1400.jpg"
      assert_equal feed2.itunes_image_file.status, "created"
      assert_nil feed2.reload.itunes_image

      feed2.itunes_image_file = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.itunes_image_file = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.itunes_image_file = {original_url: "test/fixtures/transistor1400.jpg"}
      feed2.save!
      assert_equal feed2.itunes_images.count, 1
    end

    it "deletes images" do
      refute_empty feed1.itunes_images

      feed1.itunes_image_file = nil
      assert_empty feed1.reload.itunes_images
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

  describe "#apple_credentials" do
    it "has apple credentials" do
      creds = create(:apple_credential, public_feed: feed1, private_feed: feed2)
      assert_equal feed1.apple_credentials, [creds]
      assert_equal feed1.apple_credentials.first.private_feed, feed2
    end
  end

  describe "#publish_to_apple?" do
    it "returns true if the feed has apple credentials" do
      creds = create(:apple_credential, public_feed: feed1, private_feed: feed2, publish_enabled: true)
      assert feed1.publish_to_apple?(creds)
      refute feed2.publish_to_apple?(creds)
    end

    it "returns false if the creds are not marked publish_enabled?" do
      creds = create(:apple_credential, public_feed: feed1, private_feed: feed2, publish_enabled: false)
      refute feed1.publish_to_apple?(creds)
    end

    it "returns false if the feed does not have apple credentials" do
      refute feed1.publish_to_apple?(create(:apple_credential, public_feed: create(:feed), private_feed: create(:feed)))
    end
  end
end
