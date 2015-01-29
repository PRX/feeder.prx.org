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
