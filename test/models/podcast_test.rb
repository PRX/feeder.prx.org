require 'test_helper'

describe Podcast do
  let(:podcast) { create(:podcast) }

  it 'has episodes' do
    podcast.must_respond_to(:episodes)
  end

  it 'must have an iTunes image' do
    podcast.itunes_image.destroy
    podcast.reload

    podcast.wont_be(:valid?)
  end

  it 'must have a feed image' do
    podcast.feed_image.destroy
    podcast.reload

    podcast.wont_be(:valid?)
  end

  it 'has iTunes categories' do
    podcast.must_respond_to(:itunes_categories)
  end

  it 'updates last build date after update' do
    Timecop.freeze
    podcast.update_attributes(managing_editor: 'Brian Fernandez')

    podcast.last_build_date.must_equal Time.now

    Timecop.return
  end

  describe 'episode limit' do
    let(:episodes) { create_list(:episode, 10, podcast: podcast).reverse }

    it 'returns only limited number of episodes' do
      episodes.count.must_equal podcast.episodes.count
      podcast.feed_episodes.count.must_equal 10
      podcast.max_episodes = 5
      podcast.feed_episodes.count.must_equal 5
    end
  end
end
