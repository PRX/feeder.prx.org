require 'test_helper'

describe Content do
  let(:episode) { create(:episode) }
  let(:content) { Content.new(original_url: 'u', file_size: 10, mime_type: 'mt', episode: episode) }
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
    c.is_default.wont_equal true
    c.bit_rate.must_equal 64
    c.channels.must_equal 1
    c.duration.must_equal 3252.19
    c.expression.must_equal "sample"
    c.file_size.must_equal 26017749
    c.lang.must_equal "en"
    c.medium.must_equal "audio"
    c.sample_rate.must_equal 44100
    c.mime_type.must_equal "audio/mpeg"
    c.original_url.must_equal "https://s3.amazonaws.com/prx-dovetail/testserial/serial_audio.mp3"
  end

  it 'can be updated' do
    content.update_with_content(crier_content)
    content.original_url.must_equal "https://s3.amazonaws.com/prx-dovetail/testserial/serial_audio.mp3"
    content.file_size.must_equal 26017749
    content.mime_type.must_equal 'audio/mpeg'
  end
end
