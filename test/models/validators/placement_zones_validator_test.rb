require 'test_helper'

describe PlacementZonesValidator do
  let(:feed) { build(:feed) }

  it 'allows nil' do
    feed.filter_zones = nil
    assert feed.valid?

    feed.filter_zones = {}
    refute feed.valid?

    feed.filter_zones = []
    assert feed.valid?
  end

  it 'validates zone types' do
    feed.filter_zones = ['anything']
    refute feed.valid?

    feed.filter_zones = ['z', 'a', 'o']
    refute feed.valid?

    feed.filter_zones = ['a', 'o', 'i']
    assert feed.valid?
  end
end
