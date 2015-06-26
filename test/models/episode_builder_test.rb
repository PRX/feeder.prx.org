require 'test_helper'

describe EpisodeBuilder do
  before do
    stub_requests_to_prx_cms
    @record = build_stubbed(:episode, prx_uri: "/api/v1/stories/87683", overrides: nil)
    @record.created_at, @record.updated_at = [Time.now, Time.now + 1.day]

    @ep = EpisodeBuilder.from_prx_story(@record)
  end

  describe 'without overrides' do
    it 'gets the right story from the prx api' do
      @ep[:title].must_equal "Virginity, Fidelity, and Fertility"
    end

    it 'gets audio file type' do
      @ep[:audio_file_type].must_equal "audio/mpeg"
    end

    it 'appends podtrac redirect to audio file link' do
      link = "/pub/472875466d225aca0480000fea4b5fc2/0/web/audio_file/451642/broadcast/Moth1301GarrisonFinal.mp3"
      prefix = EpisodeBuilder.new(@record).prefix + "mp3"

      @ep[:audio_file].must_equal prefix + link
    end

    it 'gets author info' do
      @ep[:author_name].must_equal "The Moth"
    end
  end

  describe 'with overrides' do
    it 'includes overrides' do
      @record.overrides = { title: 'Virginity & Fidelity' }

      @ep = EpisodeBuilder.from_prx_story(@record)

      @ep[:title].must_equal "Virginity & Fidelity"
      @ep[:author_name].must_equal "The Moth"
    end
  end
end
