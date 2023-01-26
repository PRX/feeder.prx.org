require "test_helper"

describe Enclosure do
  let(:episode) { create(:episode) }
  let(:enclosure) { Enclosure.create(url: "u", file_size: 10, mime_type: "mt", episode: episode) }
  let(:crier_enclosure) {
    {
      "url" => "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3",
      "type" => "audio/mpeg",
      "length" => 27485957
    }
  }

  it "can be constructed from feed enclosure" do
    e = Enclosure.build_from_enclosure(episode, crier_enclosure)
    assert_equal e.original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"
    assert_equal e.file_size, 27485957
    assert_equal e.mime_type, "audio/mpeg"
  end

  it "can be updated" do
    enclosure.update_with_enclosure!(crier_enclosure)
    assert_equal enclosure.original_url, "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3"
    assert_equal enclosure.file_size, 27485957
    assert_equal enclosure.mime_type, "audio/mpeg"
  end
end
