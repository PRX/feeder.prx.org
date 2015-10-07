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
    it 'gets the description' do
      eb[:description][0,4].must_equal 'Tina'
    end

    it 'handles blank description' do
      attributes = { title: 'title', shortDescription: 'short', tags: [] }
      story = Minitest::Mock.new
      story.expect(:id, 12345)
      story.expect(:attributes, attributes)

      account = Minitest::Mock.new
      account.expect(:body, 'name')
      story.expect(:account, account)

      builder = EpisodeBuilder.new(episode)
      builder.stub(:get_story, story) do
        result = builder.from_prx_story
        result[:description].must_equal ''
      end
    end

    it 'gets the right story from the prx api' do
      eb[:title].must_equal "Virginity, Fidelity, and Fertility"
    end

    it 'gets audio file type' do
      eb[:audio][:type].must_equal 'audio/mpeg'
    end

    it 'appends podtrac redirect to audio file link' do
      episode = Minitest::Mock.new
      episode.expect(:prx_uri, nil)
      episode.expect(:overrides, {})
      episode.expect(:enclosure_template, 'http://foo.com/r.{extension}/b/n/{host}{+path}')

      builder = EpisodeBuilder.new(episode)
      url = 'http://test-f.prxu.org/podcast/episode/filename.mp3'
      new_url = builder.rewrite_audio_url(url)
      new_url.must_equal('http://foo.com/r.mp3/b/n/test-f.prxu.org/podcast/episode/filename.mp3')

      # link = '/podcast/episode/filename.mp3'
      # prefix = EpisodeBuilder.new(episode).prefix + 'mp3'
      #
      # eb[:audio][:url].must_equal prefix + '/test-f.prxu.org' + link
    end
  end

  describe 'with overrides' do
    it 'includes overrides' do
      episode.overrides = { title: 'Virginity & Fidelity' }.with_indifferent_access
      eb = EpisodeBuilder.from_prx_story(episode)

      eb[:title].must_equal "Virginity & Fidelity"
    end
  end
end
