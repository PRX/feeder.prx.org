require "test_helper"

describe Apple::Config do
  describe "#valid?" do
    it "allows only one config per show feed binding" do
      podcast = create(:podcast)
      binding = create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast))
      key = create(:apple_key, account_id: podcast.account_id)
      create(
        :apple_config,
        feed: create(:private_feed, podcast: podcast),
        key: key,
        show_feed_binding: binding
      )
      config = build(
        :apple_config,
        feed: create(:private_feed, podcast: podcast),
        key: key,
        show_feed_binding: binding
      )

      refute config.valid?
      assert_equal ["has already been taken"], config.errors[:show_feed_binding_id]
    end

    it "requires the show feed binding to belong to the same podcast" do
      binding = create(:apple_show_feed_binding)
      config = build(
        :apple_config,
        feed: create(:private_feed, podcast: create(:podcast)),
        show_feed_binding: binding
      )

      refute config.valid?
      assert_equal ["must belong to the same podcast as feed"], config.errors[:show_feed_binding]
    end

    it "is unique to a podcast" do
      podcast = create(:podcast)
      f1 = create(:feed, podcast: podcast)
      c1 = create(:apple_config, feed: f1)
      assert c1.valid?

      f2 = create(:feed, podcast: podcast)
      c2 = build(:apple_config, feed: f2)
      refute c2.valid?
      assert_equal ["podcast already has an apple config"], c2.errors[:feed]

      # can't have 2 on same feed either
      c3 = build(:apple_config, feed: f1)
      refute c3.valid?
      assert_equal ["podcast already has an apple config"], c2.errors[:feed]
    end

    it "cannot be the default feed" do
      podcast = create(:podcast)
      c1 = build(:apple_config, feed: podcast.default_feed)
      refute c1.valid?
      assert_equal ["cannot use default feed"], c1.errors[:feed]
    end
  end

  it "assigns a new key to the podcast account" do
    podcast = build(:podcast, prx_account_uri: "/api/v1/accounts/456")
    config = build(:apple_config, feed: build(:private_feed, podcast: podcast))

    config.valid?

    assert_equal 456, config.key.account_id
  end

  it "delegates associations" do
    podcast = build_stubbed(:podcast)
    public_feed = podcast.default_feed
    private_feed = build_stubbed(:private_feed, podcast: podcast)
    config = build_stubbed(:apple_config, feed: private_feed)

    assert_equal podcast, config.podcast
    assert_equal podcast.id, config.podcast_id
    assert_equal podcast.title, config.podcast_title
    assert_equal public_feed, config.public_feed
    assert_equal private_feed, config.private_feed
  end
end
