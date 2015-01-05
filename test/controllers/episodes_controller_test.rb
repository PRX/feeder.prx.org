require 'test_helper'

describe EpisodesController do
  let(:podcast) { create(:podcast) }

  it 'creates a new episode from a PRX ID' do
    post(:create, { episode: { prx_id: 87683,
                               overrides: { title: 'Virginity & Fidelity' } },
                    podcast: { prx_id: podcast.prx_id } })

    episode = Episode.find_by(prx_id: 87683)

    episode.wont_be :nil?
    episode.podcast.must_equal podcast
    JSON.parse(episode.overrides)["title"].must_equal 'Virginity & Fidelity'
  end
end
