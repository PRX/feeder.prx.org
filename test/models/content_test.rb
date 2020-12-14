require 'test_helper'

describe Content do
  let(:episode) { create(:episode) }
  let(:content) { Content.create(original_url: 'u', file_size: 10, mime_type: 'mt', episode: episode) }
  let(:crier_content) {
    {
      "position" => 1,
      "url" => "https://s3.amazonaws.com/prx-dovetail/testserial/serial_audio.mp3",
      "type" => "audio/mpeg",
      "file_size" => 26017749,
      "medium" => "audio",
      "expression" => "sample",
      "bitrate" => 64,
      "samplingrate" => "44.1",
      "channels" => 1,
      "duration" => "3252.19",
      "lang" => "en"
    }
  }

  it 'can be constructed from feed content' do
    c = Content.build_from_content(episode, crier_content)
    refute c.is_default
    assert_equal c.bit_rate, 64
    assert_equal c.channels, 1
    assert_equal c.duration, 3252.19
    assert_equal c.expression, "sample"
    assert_equal c.file_size, 26017749
    assert_equal c.lang, "en"
    assert_equal c.medium, "audio"
    assert_equal c.sample_rate, 44100
    assert_equal c.mime_type, "audio/mpeg"
    assert_equal c.original_url, "https://s3.amazonaws.com/prx-dovetail/testserial/serial_audio.mp3"
  end

  it 'can be updated' do
    content.update_with_content!(crier_content)
    assert_equal content.original_url, "https://s3.amazonaws.com/prx-dovetail/testserial/serial_audio.mp3"
    assert_equal content.file_size, 26017749
    assert_equal content.mime_type, 'audio/mpeg'
  end
end
