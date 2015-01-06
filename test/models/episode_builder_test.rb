require 'test_helper'

describe EpisodeBuilder do
  before :all do
    stub_requests_to_prx_cms

    @ep = EpisodeBuilder.from_prx_story(prx_id: 87683)
  end

  describe 'without overrides' do
    it 'gets the right story from the prx api' do
      @ep[:title].must_equal "Virginity, Fidelity, and Fertility"
    end

    it 'gets audio file info' do
      @ep[:audio_file].must_equal "/pub/472875466d225aca0480000fea4b5fc2/0/web/audio_file/451642/broadcast/Moth1301GarrisonFinal.mp3"
      @ep[:audio_file_type].must_equal "audio/mpeg"
    end

    it 'gets author info' do
      @ep[:author_name].must_equal "The Moth"
    end

    it 'gets image info' do
      @ep[:image].must_equal "/api/v1/story_images/203874"
    end
  end

  describe 'with overrides' do
    it 'includes overrides' do
      overrides = { title: 'Virginity & Fidelity' }.to_json

      @ep = EpisodeBuilder.from_prx_story(prx_id: 87683,
                                          overrides: overrides)

      @ep[:title].must_equal "Virginity & Fidelity"
      @ep[:author_name].must_equal "The Moth"
    end
  end
end
