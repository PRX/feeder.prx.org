require "test_helper"

describe SubscribeLink do
  let(:podcast) { create(:podcast, guid: "abcdefghij") }
  let(:apple_link) { SubscribeLink.create(platform: "apple", podcast: podcast, external_id: "12345") }
  let(:unique_link) { SubscribeLink.create(platform: "spotify", podcast: podcast, external_id: "99999") }
  let(:feed_link) { SubscribeLink.create(platform: "antenna", podcast: podcast, external_id: podcast.public_url) }
  let(:guid_link) { SubscribeLink.create(platform: "castamatic", podcast: podcast, external_id: podcast.guid) }
  let(:podindex_link) { SubscribeLink.create(platform: "fountain", podcast: podcast, external_id: "5678") }

  describe "#valid?" do
    it "requires a currently supported platform" do
      assert apple_link.valid?
      apple_link.platform = "wnyc"
      refute apple_link.valid?
      apple_link.platform = nil
      refute apple_link.valid?
    end

    it "requires an external id" do
      assert apple_link.valid?
      apple_link.external_id = nil
      refute apple_link.valid?
    end

    it "validates unique platforms" do
      assert apple_link.valid?
      podcast.save!

      apple_2 = SubscribeLink.create(platform: "apple", podcast: podcast, external_id: "12345")
      assert apple_link.valid?
      refute apple_2.valid?
    end
  end

  describe ".href" do
    it "substitutes appleID variable using the external id for apple platforms" do
      assert_equal apple_link.href, "https://podcasts.apple.com/podcast/id12345"
    end

    it "substitutes uniquePlatformID variable using the external id for unique platforms" do
      assert_equal unique_link.href, "https://open.spotify.com/99999"
    end

    it "substitutes feedURL variable using the external id for feed platforms, and encodes it as necessary" do
      assert_equal feed_link.href, "https://antennapod.org/deeplink/subscribe?url=http://feeds.feedburner.com/thornmorris"

      base64_link = SubscribeLink.create(platform: "youtube_feed", podcast: podcast, external_id: podcast.public_url)
      assert_equal base64_link.href, "https://music.youtube.com/library/podcasts?addrssfeed=#{Base64.encode64("http://feeds.feedburner.com/thornmorris")}"

      encodeuri_link = SubscribeLink.create(platform: "breez", podcast: podcast, external_id: podcast.public_url)
      assert_equal encodeuri_link.href, "https://breez.link/p?feedURL=#{CGI.escape("http://feeds.feedburner.com/thornmorris")}"

      hex_link = SubscribeLink.create(platform: "podguru_feed", podcast: podcast, external_id: podcast.public_url)
      assert_equal hex_link.href, "https://app.podcastguru.io/podcast/X#{hex_link.bin_to_hex("http://feeds.feedburner.com/thornmorris")}"
    end

    it "substitutes podcastGUID variable using the external id for guid platforms" do
      assert_equal guid_link.href, "https://castamatic.com/guid/abcdefghij"
    end

    it "substitutes podcastIndexShowID variable using the external id for pod index platforms" do
      assert_equal podindex_link.href, "https://fountain.fm/show/5678"
    end
  end

  describe ".as_json" do
    it "returns a hash including an href and the text of the platform" do
      assert_equal apple_link.as_json, {href: "https://podcasts.apple.com/podcast/id12345", text: "Apple Podcasts"}
    end
  end
end
