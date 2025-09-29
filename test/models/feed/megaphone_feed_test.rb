require "test_helper"

describe Feeds::MegaphoneFeed do
  let(:podcast) { create(:podcast, default_feed: default_feed) }
  let(:default_feed) { build(:default_feed, audio_format: nil) }
  let(:megaphone_feed) { build(:megaphone_feed, podcast: podcast) }

  it "sets the audio format to the default" do
    mf = Feeds::MegaphoneFeed.new(podcast: podcast)
    assert_equal mf.audio_format, Feeds::MegaphoneFeed::DEFAULT_AUDIO_FORMAT
  end

  it "validates audio format must be mp3" do
    mf = build(:megaphone_feed, podcast: podcast, audio_format: {f: "flac", b: 16, c: 2, s: 44100})
    assert_equal mf.audio_format[:f], "flac"
    refute mf.valid?
    assert_includes mf.errors[:audio_format], "must be mp3"
  end
end
