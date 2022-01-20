require 'test_helper'

describe PlacementZonesValidator do
  let(:feed) { build(:feed) }

  it 'allows nil' do
    feed.reject_zones = nil
    assert feed.valid?

    feed.reject_zones = {}
    refute feed.valid?

    feed.reject_zones = []
    assert feed.valid?
  end

  it 'validates zone types' do
    feed.reject_zones = ['anything']
    refute feed.valid?

    feed.reject_zones = ['z', 'a', 'o']
    refute feed.valid?

    feed.reject_zones = ['a', 'o', 'i']
    assert feed.valid?
  end
end
