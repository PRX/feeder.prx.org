require 'test_helper'

describe Enclosure do

  let(:enclosure) { Enclosure.new(url: 'u', file_size: 10, mime_type: 'mt') }
  let(:crier_enclosure) {
    {
      "url" => "http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3",
      "type" => "audio/mpeg",
      "length" => 27485957
    }
  }

  it 'can be constructed from feed enclosure' do
    e = Enclosure.build_from_enclosure(crier_enclosure)
    e.url.must_equal 'http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3'
    e.file_size.must_equal 27485957
    e.mime_type.must_equal 'audio/mpeg'
  end

  it 'can be updated' do
    enclosure.update_with_enclosure(crier_enclosure)
    enclosure.url.must_equal 'http://dts.podtrac.com/redirect.mp3/files.serialpodcast.org/sites/default/files/podcast/1445350094/serial-s01-e12.mp3'
    enclosure.file_size.must_equal 27485957
    enclosure.mime_type.must_equal 'audio/mpeg'
  end
end
