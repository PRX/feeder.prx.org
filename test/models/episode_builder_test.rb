require 'test_helper'

describe EpisodeBuilder do
  before :all do
    if use_webmock?
      stub_request(:get, 'https://hal.prx.org/api/v1').
        to_return(status: 200, body: json_file(:prx_root), headers: {})

      stub_request(:get, 'https://hal.prx.org/api/v1/stories/87683').
        to_return(status: 200, body: json_file(:prx_story), headers: {})

      stub_request(:get, 'https://hal.prx.org/api/v1/accounts/45139').
        to_return(status: 200, body: json_file(:prx_account), headers: {})

      stub_request(:get, 'https://hal.prx.org/api/v1/audio_files/451642').
        to_return(status: 200, body: json_file(:prx_audio_file), headers: {})

      stub_request(:get, "https://hal.prx.org/api/v1/story_images/203874").
        to_return(status: 200, body: json_file(:prx_story_image), headers: {})
    end

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
      @ep = EpisodeBuilder.from_prx_story(prx_id: 87683,
                                          overrides: { title: 'Virginity & Fidelity' })

      @ep[:title].must_equal "Virginity & Fidelity"
      @ep[:author_name].must_equal "The Moth"
    end
  end
end
