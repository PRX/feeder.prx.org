require 'test_helper'

describe PlacementZonesValidator do
  let(:feed) { build(:feed) }

  it 'allows nil' do
    feed.include_zones = nil
    assert feed.valid?

    feed.include_zones = {}
    refute feed.valid?

    feed.include_zones = []
    assert feed.valid?
  end

  it 'validates zone types' do
    feed.include_zones = ['anything']
    refute feed.valid?

    feed.include_zones = ['z', 'a', 'i']
    refute feed.valid?

    feed.include_zones = ['a', 'b', 'i']
    assert feed.valid?
  end
end
