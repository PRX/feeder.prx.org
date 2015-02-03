require 'test_helper'

describe EpisodesController do
  before do
    Timecop.freeze(Time.local(2015, 1, 13))
    @podcast = create(:podcast)

    post(:create, {
      episode: {
        prx_id: 87683,
        overrides: {
          title: 'Virginity & Fidelity'
        }
      },
      podcast: {
        prx_id: @podcast.prx_id
      }
    })
  end

  after do
    Timecop.return
  end

  describe '#create' do
    it 'creates a new episode from a PRX ID' do
      episode = Episode.find_by(prx_id: 87683)

      episode.wont_be :nil?
      episode.podcast.must_equal @podcast
      JSON.parse(episode.overrides)["title"].must_equal 'Virginity & Fidelity'
    end

    it 'updates podcast last build date and pub date' do
      @podcast.reload

      @podcast.last_build_date.must_equal Time.now
      @podcast.pub_date.must_equal Time.now
    end
  end

  describe '#edit' do
    before do
      Timecop.freeze(Time.local(2015, 2, 13))
      @episode = @podcast.episodes.first

      patch(:update, {
        id: @episode.id,
        episode: {
          overrides: {
            title: 'New Title'
          }
        }
      })
    end

    after do
      Timecop.return
    end

    it 'edits the episode overrides' do
      @episode.reload

      JSON.parse(@episode.overrides)["title"].must_equal 'New Title'
    end

    it 'updates the podcast dates' do
      @podcast.reload

      @podcast.last_build_date.must_equal Time.now
      @podcast.pub_date.must_equal Time.now
    end
  end
end
