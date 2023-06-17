require "test_helper"
require "cms_syncher"

describe CmsSyncher do
  let(:user_id) { 123 }
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast) }
  let(:image) { create(:feed_image, feed: feed) }
  let(:image) { create(:itunes_image, feed: feed) }
  let(:episode) { create(:episode_with_media, podcast: podcast) }

  let(:syncher) { CmsSyncher.new }

  it "synchs a cms series to a podcast" do
    refute_nil podcast
    series = syncher.sync_series(podcast, user_id)
    assert_equal podcast.title, series.title
  end

  it "synchs a cms story to an episode" do
    refute_nil episode
    story = syncher.sync_story(episode, user_id)
    assert_equal episode.title, story.title
  end
end
