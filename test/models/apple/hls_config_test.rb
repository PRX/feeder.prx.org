require "test_helper"

module Apple
  describe HlsConfig do
    let(:podcast) do
      podcast = create(:podcast)
      podcast.update!(apple_key: create(:apple_key, account_id: podcast.account_id))
      podcast
    end
    let(:binding) { create(:apple_show_feed_binding, feed: create(:public_feed, podcast: podcast), apple_show_id: "show-1") }

    def stub_show(video_enabled, status: 200)
      body = {data: {id: "show-1", type: "shows", attributes: {alternateAssetVideoEnabled: video_enabled}}}.to_json
      stub_request(:get, "https://aardvark.prx.org/shows/show-1").to_return(status: status, body: body)
    end

    it "allows one config per binding" do
      create(:apple_hls_config, show_feed_binding: binding)
      config = build(:apple_hls_config, show_feed_binding: binding)

      refute config.valid?
      assert_includes config.errors[:show_feed_binding_id], "has already been taken"
    end

    it "is destroyed with its binding" do
      config = create(:apple_hls_config, show_feed_binding: binding)

      binding.destroy!

      refute HlsConfig.exists?(config.id)
    end

    describe "#not_eligible?" do
      it "is true when enabled and Apple has not enabled video" do
        assert build(:apple_hls_config, enabled: true, video_enabled_cache: false).not_eligible?
        assert build(:apple_hls_config, enabled: true, video_enabled_cache: nil).not_eligible?
      end

      it "is false when disabled or eligible" do
        refute build(:apple_hls_config, enabled: false, video_enabled_cache: false).not_eligible?
        refute build(:apple_hls_config, enabled: true, video_enabled_cache: true).not_eligible?
      end
    end

    describe "#publishable?" do
      it "requires enabled and video-enabled" do
        assert build(:apple_hls_config, enabled: true, video_enabled_cache: true).publishable?
        refute build(:apple_hls_config, enabled: true, video_enabled_cache: false).publishable?
        refute build(:apple_hls_config, enabled: false, video_enabled_cache: true).publishable?
      end
    end

    describe "#refresh_eligibility!" do
      it "caches alternateAssetVideoEnabled through the podcast key" do
        stub_show(true)
        config = create(:apple_hls_config, show_feed_binding: binding, video_enabled_cache: nil, last_checked_at: nil)

        assert config.refresh_eligibility!
        assert config.reload.video_enabled_cache
        assert config.last_checked_at.present?
      end

      it "caches a show without video as ineligible" do
        stub_show(false)
        config = create(:apple_hls_config, show_feed_binding: binding, video_enabled_cache: true)

        refute config.refresh_eligibility!
        assert config.reload.not_eligible?
      end

      it "treats a missing flag as ineligible" do
        stub_show(nil)
        config = create(:apple_hls_config, show_feed_binding: binding)

        refute config.refresh_eligibility!
      end

      it "raises when Apple cannot read the show" do
        stub_show(true, status: 403)
        config = create(:apple_hls_config, show_feed_binding: binding, video_enabled_cache: true)

        assert_raises(Apple::ApiError) { config.refresh_eligibility! }
        assert config.reload.video_enabled_cache
      end
    end
  end
end
