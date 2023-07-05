require "test_helper"

class FeedAudioFormatTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:feed) { podcast.default_feed }
  let(:default_mp3_format) { {f: "mp3", b: 128, c: 2, s: 44100} }
  let(:default_wav_format) { {f: "wav", b: 16, c: 1, s: 8000} }
  let(:default_flac_format) { {f: "flac", b: 24, c: 2, s: 12000} }

  describe "#audio_type" do
    it "returns nil if audio format is blank" do
      feed.audio_format = {}
      assert_nil feed.audio_type
    end

    it "gets the :f value in audio_format" do
      feed.audio_format = default_mp3_format
      assert_equal feed.audio_type, "mp3"
    end
  end

  describe "#audio_type=" do
    it "sets the :f value in audio_format" do
      feed.audio_format = nil
      feed.audio_type = "mp3"
      assert_equal feed.audio_format[:f], "mp3"
    end

    it "nils audio_format if no type is selected" do
      feed.audio_format = default_mp3_format
      feed.audio_type = nil
      assert_nil feed.audio_format
    end
  end

  describe "#audio_bitrate" do
    it "returns nil if audio_format is blank" do
      feed.audio_format = {}
      assert_nil feed.audio_bitrate
    end

    it "gets the :b value in audio_format if the type is mp3" do
      feed.audio_format = default_mp3_format
      assert_equal feed.audio_bitrate, 128
    end

    it "returns nil if audio_format type is not type mp3" do
      feed.audio_format = default_wav_format
      assert_nil feed.audio_bitrate
    end
  end

  describe "#audio_bitrate=" do
    it "sets the :b value in audio_format if type is mp3" do
      feed.audio_format = default_mp3_format
      feed.audio_bitrate = 96
      assert_equal feed.audio_format[:b], 96
    end

    it "does not set any value if there is no audio_format" do
      feed.audio_format = nil
      feed.audio_bitrate = 96
      assert_nil feed.audio_format.try(:[], :b)
    end
  end

  describe "#audio_bitdepth" do
    it "returns nil if audio_format is blank" do
      feed.audio_format = {}
      assert_nil feed.audio_bitdepth
    end

    it "gets the :b value in audio_format if the type is not mp3" do
      feed.audio_format = default_wav_format
      assert_equal feed.audio_bitdepth, 16
      feed.audio_format = default_flac_format
      assert_equal feed.audio_bitdepth, 24
    end

    it "returns nil if audio_format type is mp3" do
      feed.audio_format = default_mp3_format
      assert_nil feed.audio_bitdepth
    end
  end

  describe "#audio_bitdepth=" do
    it "sets the :b value in audio_format if type is not mp3" do
      feed.audio_format = default_wav_format
      feed.audio_bitdepth = 32
      assert_equal feed.audio_format[:b], 32
      feed.audio_format = default_flac_format
      feed.audio_bitdepth = 16
      assert_equal feed.audio_format[:b], 16
    end

    it "does not set any value if there is no audio_format" do
      feed.audio_format = nil
      feed.audio_bitdepth = 16
      assert_nil feed.audio_format.try(:[], :b)
    end
  end

  describe "#audio_channel" do
    it "returns nil if audio_format is blank" do
      feed.audio_format = {}
      assert_nil feed.audio_channel
    end

    it "gets the :c value in audio_format" do
      feed.audio_format = default_mp3_format
      assert_equal feed.audio_channel, 2
    end
  end

  describe "#audio_channel=" do
    it "sets the :c value in audio_format" do
      feed.audio_format = default_mp3_format
      feed.audio_channel = 1
      assert_equal feed.audio_format[:c], 1
    end

    it "does not set any value if there is no audio_format" do
      feed.audio_format = nil
      feed.audio_channel = 1
      assert_nil feed.audio_format.try(:[], :c)
    end
  end

  describe "#audio_sample" do
    it "returns nil if audio_format is blank" do
      feed.audio_format = {}
      assert_nil feed.audio_sample
    end

    it "gets the :s value in audio_format" do
      feed.audio_format = default_mp3_format
      assert_equal feed.audio_sample, 44100
    end
  end

  describe "#audio_sample=" do
    it "sets the :s value in audio_format" do
      feed.audio_format = default_mp3_format
      feed.audio_sample = 16000
      assert_equal feed.audio_format[:s], 16000
    end

    it "does not set any value if there is no audio_format" do
      feed.audio_format = nil
      feed.audio_sample = 16000
      assert_nil feed.audio_format.try(:[], :s)
    end
  end
end
