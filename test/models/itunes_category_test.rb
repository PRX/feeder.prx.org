require 'test_helper'

describe ItunesCategory do
  let(:cat) { build_stubbed(:itunes_category) }

  it 'can have subcategories' do
    cat.must_be(:valid?)
  end

  it 'must belong to the list' do
    cat.name = 'Space'
    cat.wont_be(:valid?)
  end

  it 'must have subcategories on list' do
    cat.subcategories = 'Aviation, Space'
    cat.wont_be(:valid?)
  end

  it 'must belong to a podcast' do
    cat.podcast = nil
    cat.wont_be(:valid?)
  end
end
