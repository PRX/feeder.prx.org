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

    feed.include_zones = ['ad', 'ad2', 'sonic_id']
    refute feed.valid?

    feed.include_zones = ['ad', 'billboard', 'sonic_id']
    assert feed.valid?
  end
end
