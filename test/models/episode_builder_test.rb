require 'test_helper'

describe EpisodeBuilder do
  before do
    stub_requests_to_prx_cms
  end

  let(:episode) do
    create(:episode, prx_uri: "/api/v1/stories/87683", overrides: nil).tap do |e|
      e.created_at, e.updated_at = [Time.now, Time.now + 1.day]
     end
   end

  let(:eb) { EpisodeBuilder.from_prx_story(episode) }

  describe 'without overrides' do
    it 'gets the right story from the prx api' do
      eb[:title].must_equal "Virginity, Fidelity, and Fertility"
    end

    it 'gets audio file type' do
      eb[:audio][:type].must_equal 'audio/mpeg'
    end

    it 'appends podtrac redirect to audio file link' do
      link = '/podcast/episode/filename.mp3'
      prefix = EpisodeBuilder.new(episode).prefix + 'mp3'

      eb[:audio][:url].must_equal prefix + '/test-f.prxu.org' + link
    end

    it 'gets author info' do
      eb[:author_name].must_equal 'The Moth'
    end
  end

  describe 'with overrides' do
    it 'includes overrides' do
      episode.overrides = { title: 'Virginity & Fidelity' }.with_indifferent_access
      eb = EpisodeBuilder.from_prx_story(episode)

      eb[:title].must_equal "Virginity & Fidelity"
      eb[:author_name].must_equal "The Moth"
    end
  end
end
