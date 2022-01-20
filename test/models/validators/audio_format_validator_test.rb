require 'test_helper'

describe AudioFormatValidator do
  let(:feed) { build(:feed) }

  it 'allows nil' do
    feed.audio_format = nil
    assert feed.valid?

    feed.audio_format = {}
    refute feed.valid?
  end

  it 'validates the format type' do
    feed.audio_format = {f: 'mp3', b: 128, c: 2, s: 44100}
    assert feed.valid?

    feed.audio_format = {f: 'wav', b: 16, c: 2, s: 44100}
    assert feed.valid?

    feed.audio_format = {f: 'flac', b: 16, c: 2, s: 44100}
    assert feed.valid?

    feed.audio_format = {f: 'other', b: 16, c: 2, s: 44100}
    refute feed.valid?
  end

  it 'validates bit rates' do
    feed.audio_format = {f: 'mp3', b: 255, c: 2, s: 44100}
    refute feed.valid?

    feed.audio_format[:b] = '256'
    refute feed.valid?

    feed.audio_format[:b] = 256
    assert feed.valid?
  end

  it 'validates bit depths' do
    feed.audio_format = {f: 'wav', b: 128, c: 2, s: 44100}
    refute feed.valid?

    feed.audio_format[:b] = '24'
    refute feed.valid?

    feed.audio_format[:b] = 24
    assert feed.valid?
  end

  it 'validates channels' do
    feed.audio_format = {f: 'flac', b: 16, c: 3, s: 48000}
    refute feed.valid?

    feed.audio_format[:c] = '1'
    refute feed.valid?

    feed.audio_format[:c] = 1
    assert feed.valid?
  end

  it 'validates sample rates' do
    feed.audio_format = {f: 'wav', b: 24, c: 1, s: 45678}
    refute feed.valid?

    feed.audio_format[:s] = '22050'
    refute feed.valid?

    feed.audio_format[:s] = 22050
    assert feed.valid?
  end
end
