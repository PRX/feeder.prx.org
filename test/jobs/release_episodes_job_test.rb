require 'test_helper'

describe ReleaseEpisodesJob do

  let(:podcast) { create(:podcast, prx_uri: '/api/v1/series/20829') }
  let(:episode) { create(:episode, released_at: 2.days.ago, podcast_id: podcast.id) }

  let(:job) { ReleaseEpisodesJob.new }

  before {
    podcast.update_columns(last_build_date: 1.week.ago)
  }

  it 'gets a list of podcasts with episodes to release' do
    podcast.last_build_date.must_be :<, episode.released_at
    podcasts = job.podcasts_to_release
    podcasts.size.must_equal 1
    podcasts.first.must_equal podcast
  end

  it 'publishes the podcast if released is passed and after the last build' do
    podcast.stub(:create_publish_task, true) do
      job.stub(:podcasts_to_release, [podcast]) do
        podcast.last_build_date.must_be :<, episode.released_at
        job.perform
        podcast.last_build_date.must_be :>, episode.released_at
      end
    end
  end
end
