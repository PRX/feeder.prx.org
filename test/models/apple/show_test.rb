# frozen_string_literal: true

require "test_helper"

describe Apple::Show do
  let(:podcast) { create(:episode).podcast }
  let(:apple_api) { Apple::Api.from_delegated_delivery_config(delegated_delivery_config) }
  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:private_feed, podcast: podcast) }
  let(:show_feed_binding) { build(:apple_show_feed_binding, feed: public_feed, apple_show_id: "123") }
  let(:delegated_delivery_config) { build(:delegated_delivery_config, feed: private_feed, show_feed_binding: show_feed_binding) }
  let(:apple_show) { delegated_delivery_config.build_show }

  before do
    private_feed.set_default_episodes
  end

  describe ".from_delegated_delivery_config" do
    it "can be created from a delegated delivery config" do
      show = delegated_delivery_config.build_show
      assert show.is_a?(Apple::Show)
      assert_equal show.public_feed, public_feed
      assert_equal show.private_feed, private_feed
    end
  end

  describe ".from_show_feed_binding" do
    let(:binding) { create(:apple_show_feed_binding, feed: public_feed, apple_show_id: "hls-show") }

    before { podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id)) }

    it "routes through the binding with no delivery feed" do
      show = Apple::Show.from_show_feed_binding(binding)

      assert_equal "hls-show", show.apple_id
      assert_equal public_feed, show.public_feed
      assert_nil show.private_feed
      assert_equal podcast.apple_key.key_id, show.api.key_id
    end

    it "indexes the show's staged alternate assets by GUID" do
      body = {data: [{id: "staged-1", attributes: {guid: "guid-1"}}], links: {}}.to_json
      stub_request(:get, "https://aardvark.prx.org/shows/hls-show/stagedAlternateAssets").to_return(status: 200, body: body)

      show = Apple::Show.from_show_feed_binding(binding)

      assert_equal "staged-1", show.find_staged_alternate_asset_json_by_guid("guid-1")["id"]
      assert_nil show.find_staged_alternate_asset_json_by_guid("guid-2")
    end
  end

  describe "#reload" do
    it "flushes memoized attrs" do
      apple_show.instance_variable_set(:@apple_episode_json, "foo")
      apple_show.instance_variable_set(:@podcast_feeder_episodes, "foo")
      apple_show.instance_variable_set(:@podcast_episodes, "foo")
      apple_show.instance_variable_set(:@episodes, "foo")
      apple_show.instance_variable_set(:@episode_ids, "foo")
      apple_show.instance_variable_set(:@find_episode, "foo")
      apple_show.instance_variable_set(:@apple_id_to_apple_json, "foo")
      apple_show.instance_variable_set(:@guid_to_apple_json, "foo")
      apple_show.reload
      assert_nil apple_show.instance_variable_get(:@apple_episode_json)
      assert_nil apple_show.instance_variable_get(:@podcast_feeder_episodes)
      assert_nil apple_show.instance_variable_get(:@podcast_episodes)
      assert_nil apple_show.instance_variable_get(:@episodes)
      assert_nil apple_show.instance_variable_get(:@episode_ids)
      assert_nil apple_show.instance_variable_get(:@find_episode)
      assert_nil apple_show.instance_variable_get(:@apple_id_to_apple_json)
      assert_nil apple_show.instance_variable_get(:@guid_to_apple_json)
    end
  end

  describe "#podcast_feeder_episodes" do
    it "should return an array of Episode" do
      assert_equal apple_show.podcast_feeder_episodes.count, 1
      assert_equal apple_show.podcast_feeder_episodes.first.class, Episode
    end

    it "includes deleted episodes" do
      Episode.where(podcast_id: podcast.id).first.update!(deleted_at: Time.now.utc)

      assert_equal apple_show.podcast_feeder_episodes.count, 1
      assert apple_show.podcast_feeder_episodes.first.deleted?
    end

    it "de-duplicates episodes based on the item_guid" do
      assert_equal Episode.where(podcast_id: podcast.id).length, 1

      episode = Episode.where(podcast_id: podcast.id).first
      episode.update!(original_guid: "123", deleted_at: Time.now.utc)

      # add another episode with the same guid
      episode2 = create(:episode, podcast: podcast, item_guid: "123")

      assert_equal apple_show.podcast_feeder_episodes.count, 1
      assert_equal apple_show.podcast_feeder_episodes.first.id, episode2.id
    end

    describe "#sort_by_episode_properties" do
      it "sorts by multiple attributes in descending priority" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: now, created_at: now, id: 1),
          OpenStruct.new(deleted_at: now, published_at: now + 1.second, created_at: now, id: 2),
          OpenStruct.new(deleted_at: now, published_at: now + 1.second, created_at: now + 1.second, id: 3),
          OpenStruct.new(deleted_at: nil, published_at: now + 1.second, created_at: now + 1.second, id: 4),
          OpenStruct.new(deleted_at: nil, published_at: now + 1.second, created_at: now + 2.second, id: 5),
          OpenStruct.new(deleted_at: nil, published_at: now + 2.second, created_at: now + 2.second, id: 6)
        ]

        assert_equal [6, 5, 4, 3, 2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end

      it "sorts by presence of deleted_at" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: now, created_at: now, id: 1),
          OpenStruct.new(deleted_at: nil, published_at: now, created_at: now, id: 2)
        ]

        assert_equal [2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end

      it "sorts by presence of published_at" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: nil, created_at: now, id: 1),
          OpenStruct.new(deleted_at: now, published_at: now, created_at: now, id: 2)
        ]

        # unpublished is less than published
        assert_equal [2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end

      it "published_at falls back to created_at" do
        now = Time.now.utc

        recs = [
          OpenStruct.new(deleted_at: now, published_at: nil, created_at: now, id: 1),
          OpenStruct.new(deleted_at: now, published_at: nil, created_at: now + 1.second, id: 2)
        ]

        # unpublished is less than published
        assert_equal [2, 1], apple_show.sort_by_episode_properties(recs).map(&:id)
      end
    end
  end

  describe "#episodes" do
    it "returns an array of Apple::Episode" do
      assert_equal 1, apple_show.episodes.count
      assert_equal Apple::Episode, apple_show.episodes.first.class
      assert_equal apple_show, apple_show.episodes.first.show
    end

    it "returns memoized instances of Apple::Episode" do
      obj_id = apple_show.episodes.first.object_id
      # These are not the same objects
      assert_equal apple_show.episodes.first.object_id, obj_id
    end

    it "returns the same base Feeder Episode" do
      obj_id = apple_show.episodes.first.feeder_episode.object_id
      # These feeder episodes are the same
      assert_equal apple_show.episodes.first.feeder_episode.object_id, obj_id

      # now reload
      apple_show.reload
      refute_equal apple_show.episodes.first.feeder_episode.object_id, obj_id
    end

    it "filters out the deleted episodes" do
      assert_equal 1, apple_show.episodes.count
      apple_show.episodes.first.feeder_episode.update!(deleted_at: Time.now.utc)

      apple_show.reload
      assert_equal 0, apple_show.episodes.count
    end

    it "keeps draft episodes out of the feed-visible episode set" do
      delegated_delivery_feed = create(:delegated_delivery_feed, podcast: podcast)
      delegated_delivery_feed.set_default_episodes
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      delegated_delivery_feed.episodes << draft

      config = delegated_delivery_feed.delegated_delivery_config
      show = config.build_show

      episode_ids = show.episodes.map { |e| e.feeder_episode.id }
      refute_includes episode_ids, draft.id
      assert_includes show.draft_upload_candidates.map { |e| e.feeder_episode.id }, draft.id
    end

    it "returns a feed-visible episode only once" do
      delegated_delivery_feed = create(:delegated_delivery_feed, podcast: podcast)
      delegated_delivery_feed.set_default_episodes

      ep = create(:episode_with_media, podcast: podcast, published_at: nil)
      delegated_delivery_feed.episodes << ep

      config = delegated_delivery_feed.delegated_delivery_config
      show = config.build_show

      ep.update!(published_at: 1.hour.ago)

      ids = show.episodes.map { |e| e.feeder_episode.id }
      assert_includes ids, ep.id
      assert_equal ids.uniq, ids, "episode should appear only once"
    end

    it "excludes draft episodes without media from an apple subscription feed" do
      delegated_delivery_feed = create(:delegated_delivery_feed, podcast: podcast)
      delegated_delivery_feed.set_default_episodes
      draft = create(:episode, podcast: podcast, published_at: nil)
      delegated_delivery_feed.episodes << draft

      config = delegated_delivery_feed.delegated_delivery_config
      show = config.build_show

      episode_ids = show.episodes.map { |e| e.feeder_episode.id }
      refute_includes episode_ids, draft.id
    end
  end

  describe "#draft_upload_candidates" do
    it "excludes drafts from public delivery feeds" do
      binding = create(:apple_show_feed_binding, feed: public_feed)
      config = create(:delegated_delivery_config, feed: public_feed, show_feed_binding: binding)
      create(:episode_with_media, podcast: podcast, published_at: nil)
      create(:episode_with_media, podcast: podcast, published_at: 1.day.from_now)

      assert_empty config.build_show.draft_upload_candidates
    end

    it "returns draft episodes with media from an apple subscription feed" do
      delegated_delivery_feed = create(:delegated_delivery_feed, podcast: podcast)
      delegated_delivery_feed.set_default_episodes
      draft_with_media = create(:episode_with_media, podcast: podcast, published_at: nil)
      draft_without_media = create(:episode, podcast: podcast, published_at: nil)
      delegated_delivery_feed.episodes << draft_with_media
      delegated_delivery_feed.episodes << draft_without_media

      # Preconditions: verify the media states that drive candidate selection
      assert draft_with_media.enclosure_ready?(true), "draft_with_media should have complete media"
      refute draft_without_media.enclosure_ready?(true), "draft_without_media should not have complete media"
      refute draft_without_media.enclosure_ready?(false), "draft_without_media should have no media at all"

      config = delegated_delivery_feed.delegated_delivery_config
      show = config.build_show

      candidate_ids = show.draft_upload_candidates.map { |e| e.feeder_episode.id }
      assert_includes candidate_ids, draft_with_media.id
      refute_includes candidate_ids, draft_without_media.id
    end

    it "returns empty array for non-apple feeds" do
      config = build(:delegated_delivery_config, feed: private_feed)
      show = config.build_show

      assert_equal [], show.draft_upload_candidates
    end

    it "memoizes candidates until reload" do
      delegated_delivery_feed = create(:delegated_delivery_feed, podcast: podcast)
      delegated_delivery_feed.set_default_episodes
      draft = create(:episode_with_media, podcast: podcast, published_at: nil)
      delegated_delivery_feed.episodes << draft

      config = delegated_delivery_feed.delegated_delivery_config
      show = config.build_show

      first = show.draft_upload_candidates
      assert_same first, show.draft_upload_candidates

      show.reload
      refute_same first, show.draft_upload_candidates
    end
  end

  describe "#sync!" do
    it "runs sync!" do
      log_public_feed_sync!
      apple_show.api.stub(:get, OpenStruct.new(body: {"data" => {"id" => "123", "attributes" => {"foo" => "bar"}}}.to_json, code: "200")) do
        assert apple_show.sync_log.present?

        sync = apple_show.sync!

        assert_instance_of Apple::SyncLog, sync

        assert_equal "123", sync.external_id
        assert_equal "123", apple_show.apple_id
        assert_equal "bar", apple_show.apple_attributes["foo"]
      end
    end

    it "creates a sync log if one does not exist" do
      apple_show.api.stub(:get, OpenStruct.new(body: {"data" => {"id" => "123", "attributes" => {"foo" => "bar"}}}.to_json, code: "200")) do
        assert_nil apple_show.sync_log

        sync = apple_show.sync!

        assert_equal "123", sync.external_id
        assert_equal "123", apple_show.apple_id
        assert_equal "bar", apple_show.apple_attributes["foo"]
      end
    end

    it "syncs the bound show when no public-feed sync log exists" do
      config, binding = create_bound_config("bound-show")
      response = OpenStruct.new(body: {"data" => {"id" => "bound-show", "attributes" => {"foo" => "bar"}}}.to_json, code: "200")

      show = config.build_show
      get_show = lambda do |path|
        assert_equal "shows/bound-show", path
        response
      end

      assert_nil show.sync_log
      show.api.stub(:get, get_show) do
        sync = show.sync!

        assert_equal "bound-show", sync.external_id
        assert_equal binding.apple_show_id, show.apple_id
        assert_equal "bar", show.apple_attributes["foo"]
      end
    end

    it "syncs the bound show and replaces a stale public-feed sync id" do
      config, binding = create_bound_config("bound-show")
      stale_log = SyncLog.log!(
        integration: :apple,
        feeder_type: :feeds,
        feeder_id: binding.feed_id,
        external_id: "stale-show"
      )
      response = OpenStruct.new(body: {"data" => {"id" => "bound-show", "attributes" => {}}}.to_json, code: "200")

      show = config.build_show
      get_show = lambda do |path|
        assert_equal "shows/bound-show", path
        response
      end

      show.api.stub(:get, get_show) do
        sync = show.sync!

        assert_equal stale_log.id, sync.id
        assert_equal "bound-show", sync.external_id
      end
    end

    it "rejects a response for a different show than the binding" do
      config, binding = create_bound_config("bound-show")
      response = OpenStruct.new(body: {"data" => {"id" => "different-show", "attributes" => {}}}.to_json, code: "200")

      show = config.build_show

      show.api.stub(:get, response) do
        error = assert_raises(RuntimeError) { show.sync! }

        assert_match(/Apple show id mismatch/, error.message)
        assert_nil binding.feed.reload.apple_sync_log
      end
    end

    it "raises an api error when show sync returns an http error" do
      log_public_feed_sync!
      apple_show.sync_log.update!(api_response: {"before" => true})
      response = OpenStruct.new(body: "<html>503 Service Unavailable</html>", code: "503")

      apple_show.api.stub(:get, response) do
        error = assert_raises(Apple::ApiError) do
          apple_show.sync!
        end

        assert_includes error.message, "HTTP resp code:503"
        assert_includes error.message, "503 Service Unavailable"
        assert_equal({"before" => true}, apple_show.sync_log.reload.api_response)
      end
    end

    it "logs an incomplete sync record if the upsert fails" do
      raises_exception = -> { raise Apple::ApiError.new("Error", OpenStruct.new(code: 200, body: "body")) }

      apple_show.stub(:fetch_show, raises_exception) do
        assert_raises(Apple::ApiError) do
          apple_show.sync!
        end
        assert_nil apple_show.sync_log
      end
    end
  end

  describe "#guid_to_apple_json" do
    it "should memoize the guid_to_apple_json without calling apple_episode_json" do
      data = {"foo" => "bar"}

      apple_show.instance_variable_set(:@guid_to_apple_json, data)

      mock = Object.new
      def mock.call(*)
        raise "apple_episode_json should not have been called!"
      end

      apple_show.stub(:apple_episode_json, mock) do
        assert_equal "bar", apple_show.guid_to_apple_json("foo")
      end
    end

    it "falls back to apple_episode_json when not memoized" do
      apple_show.reload

      data = {"attributes" => {"guid" => "foo", "data" => "frob"}}
      apple_show.stub(:apple_episode_json, [data]) do
        assert_equal apple_show.guid_to_apple_json("foo"), {"attributes" => {"guid" => "foo", "data" => "frob"}}
      end
    end
  end

  def create_bound_config(show_id)
    key = create(:apple_key, account_id: public_feed.podcast.account_id)
    public_feed.podcast.update!(apple_key: key)
    binding = create(
      :apple_show_feed_binding,
      feed: public_feed,
      apple_show_id: show_id
    )
    config = create(
      :delegated_delivery_config,
      feed: private_feed,
      key: key,
      show_feed_binding: binding
    )

    [config, binding]
  end

  def log_public_feed_sync!
    SyncLog.log!(integration: :apple, feeder_type: :feeds, feeder_id: apple_show.public_feed.id, external_id: "123")
    apple_show.public_feed.association(:apple_sync_log).reset
  end
end
