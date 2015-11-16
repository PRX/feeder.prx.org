require 'test_helper'

describe EpisodeRepresenter do
  let(:episode) { build_stubbed(:episode) }
  let(:representer) { EpisodeRepresenter.new(episode) }

  it 'includes the guid' do
    episode.stub(:guid, 'guid') do
      representer.as_json['guid'].must_equal 'prx:jjgo:guid'
    end
  end

  it 'includes the original guid if set' do
    episode.stub(:original_guid, 'original-guid') do
      representer.as_json['guid'].must_equal 'original-guid'
    end
  end

  it 'includes the duration' do
    episode.stub(:duration, 123) do
      representer.as_json['duration'].must_equal 123
    end
  end

  it 'includes audio files' do
    episode.stub(:audio_files, [:sym]) do
      representer.as_json['audio'].must_equal ['sym']
    end
  end

  it 'includes the published date' do
    date = DateTime.parse('16:11 October 29, 1987 EST')
    episode.stub(:published, date) do
      DateTime.parse(representer.as_json['published']).must_equal date
    end
  end
end
