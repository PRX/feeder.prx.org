require "test_helper"

describe ReleaseEpisodesJob do
  let(:podcast) { create(:podcast, prx_uri: "/api/v1/series/20829") }
  let(:episode) { create(:episode, podcast_id: podcast.id) }

  let(:job) { ReleaseEpisodesJob.new }

  before {
    podcast.update_columns(updated_at: 1.week.ago)
  }

  it "publishes the podcast if released is passed and after the last build" do
    episode.update_columns(updated_at: 1.day.ago, published_at: 1.hour.ago)
    Episode.stub(:episodes_to_release, [episode]) do
      assert_operator episode.updated_at, :<, episode.published_at
      job.perform
      assert_operator podcast.reload.updated_at, :>, episode.published_at
    end
  end
end
