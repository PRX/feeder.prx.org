require "test_helper"

describe Content do
  let(:episode) { create(:episode) }
  let(:content) { Content.create(original_url: "u", file_size: 10, mime_type: "mt", episode: episode) }
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
end
