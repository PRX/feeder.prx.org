require 'test_helper'

describe ReleaseEpisodesJob do

  let(:podcast) { create(:podcast, prx_uri: '/api/v1/series/20829') }

  let(:job) { ReleaseEpisodesJob.new }

  it 'gets a list of podcasts with episodes to release' do
    podcasts = job.podcasts_to_release
    podcasts.first.must_be_nil

    episode = create(:episode, released_at: 2.days.ago, podcast_id: podcast.id)
    episode2 = create(:episode, released_at: 2.days.ago, podcast_id: podcast.id)
    podcast.update_columns(last_build_date: 1.week.ago)

    podcast.last_build_date.must_be :<, episode.released_at
    podcasts = job.podcasts_to_release
    podcasts.size.must_equal 1
    podcasts.first.must_equal podcast
  end
end
