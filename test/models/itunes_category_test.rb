require 'test_helper'

describe ITunesCategory do
  let(:cat) { build_stubbed(:itunes_category) }

  it 'is valid when all attributes are valid' do
    cat.must_be(:valid?)
  end

  it 'must have a name on the list' do
    cat.name = 'Space'
    cat.wont_be(:valid?)
  end

  it 'must have subcategories on list' do
    cat.subcategories = 'Aviation, Space'
    cat.wont_be(:valid?)
  end

  it 'must have subcategories that correspond to category' do
    cat.subcategories = 'Aviation, Literature'
    cat.wont_be(:valid?)
    cat.errors[:subcategories].must_include "Literature is not a valid subcategory"
  end

  it 'must belong to a podcast' do
    cat.podcast = nil
    cat.wont_be(:valid?)
  end
end
