require 'test_helper'
require 'feed_decorator'

describe Feed do
  let(:feed) { create(:feed, overrides: { title: 'feed override', fake: 'nope' } ) }

  describe 'feed overrides podcast attributes' do
    it 'has overrides' do
      feed.overrides['title'].must_equal 'feed override'
    end

    it 'has overrides for some values' do
      feed.overridden?('title').must_equal true
      feed.overridden?(:title).must_equal true
      feed.overridden?(:fake).must_equal false
      feed.overridden?('fake').must_equal false
      feed.overridden?('nonexistent').must_equal false
    end
  end
end
