require 'test_helper'
require 'feed_decorator'

describe FeedDecorator do
  let(:raw_feed) { create(:feed, overrides: { title: 'feed override' } ) }
  let(:podcast) { raw_feed.podcast }
  let(:feed) { FeedDecorator.new(raw_feed) }

  describe 'feed overrides the podcast' do
    it 'has a different title' do
      feed.title.must_equal 'feed override'
    end

    describe 'episode limit' do
      let(:episodes) { create_list(:episode, 10, podcast: podcast).reverse }

      it 'returns only limited number of episodes' do
        episodes.count.must_equal feed.episodes.count
        feed.feed_episodes.count.must_equal 10

        feed.overrides[:display_episodes_count] = 8
        feed.feed_episodes.count.must_equal 8

        feed.overrides['display_episodes_count'] = 5
        feed.feed_episodes.count.must_equal 5
      end
    end
  end

  describe 'feed delegates to the podcast' do
    it 'has episodes' do
      feed.episodes.count.must_equal 0
    end

    it 'has iTunes categories' do
      feed.itunes_categories.first.name.must_equal 'Leisure'
    end

    it 'is episodic or serial' do
      feed.itunes_type.must_match /episodic/
      feed.overrides['itunes_type'] = 'serial'
      feed.itunes_type.must_match /serial/
    end

    it 'sets the itunes block to false by default' do
      feed.wont_be :itunes_block
      feed.overrides['itunes_block'] = true
      feed.must_be :itunes_block
    end
  end
end
