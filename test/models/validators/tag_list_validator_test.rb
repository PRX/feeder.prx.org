require 'test_helper'

describe TagListValidator do
  let(:feed) { build(:feed) }

  it 'allows nil' do
    feed.filter_tags = nil
    assert feed.valid?

    feed.filter_tags = {}
    refute feed.valid?

    feed.filter_tags = []
    assert feed.valid?
  end

  it 'validates string tags' do
    feed.filter_tags = ['anything', 333]
    refute feed.valid?

    feed.filter_tags = ['tag', 'tag', Object.new]
    refute feed.valid?

    feed.filter_tags = ['tag', 'tag with spaces ', '1234']
    assert feed.valid?
  end
end
