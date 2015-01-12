require 'test_helper'

describe EpisodesController do
  before do
    @podcast = create(:podcast)
    @now = DateTime.parse('Jan 13, 2015')

    Time.stub(:now, @now) do
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
  end

  it 'creates a new episode from a PRX ID' do
    episode = Episode.find_by(prx_id: 87683)

    episode.wont_be :nil?
    episode.podcast.must_equal @podcast
    JSON.parse(episode.overrides)["title"].must_equal 'Virginity & Fidelity'
  end

  it 'updates podcast last build date and pub date' do
    @podcast.reload

    @podcast.last_build_date.must_equal @now
    @podcast.pub_date.must_equal @now
  end
end
