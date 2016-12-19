require 'test_helper'

describe ReleaseEpisodesJob do

  let(:podcast) { create(:podcast, prx_uri: '/api/v1/series/20829') }
  let(:episode) { create(:episode, podcast_id: podcast.id) }

  let(:job) { ReleaseEpisodesJob.new }

  before {
    podcast.update_columns(updated_at: 1.week.ago)
  }

  it 'gets a list of episodes to release' do
    episode.update_columns(updated_at: 1.day.ago, published_at: 1.hour.ago)
    podcast.last_build_date.must_be :<, episode.published_at
    episodes = job.episodes_to_release
    episodes.size.must_equal 1
    episodes.first.must_equal episode
  end

  it 'publishes the podcast if released is passed and after the last build' do
    episode.update_columns(updated_at: 1.day.ago, published_at: 1.hour.ago)
    episode.podcast.stub(:create_publish_task, true) do
      job.stub(:episodes_to_release, [episode]) do
        episode.updated_at.must_be :<, episode.published_at
        job.perform
        podcast.reload.updated_at.must_be :>, episode.published_at
      end
    end
  end
end
