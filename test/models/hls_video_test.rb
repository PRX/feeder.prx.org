require "test_helper"

describe HlsVideo do
  let(:hls) { build_stubbed(:hls_video) }

  describe "#valid?" do
    it "must be video when complete" do
      assert hls.valid?
      assert hls.status_created?

      hls.medium = "audio"
      assert hls.valid?

      hls.status = "complete"
      refute hls.valid?

      hls.medium = "video"
      assert hls.valid?
    end

    it "must have a duration greater than 0 when complete" do
      assert hls.valid?
      assert hls.status_created?

      hls.duration = 0
      hls.status = "complete"
      refute hls.valid?

      hls.duration = 100
      assert hls.valid?
    end
  end
end
