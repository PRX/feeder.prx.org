require 'test_helper'

describe ITunesCategory do
  let(:cat) { build_stubbed(:itunes_category) }

  it 'is valid when all attributes are valid' do
    assert cat.valid?
  end

  it 'must have a name on the list' do
    cat.name = 'Space'
    refute cat.valid?
  end

  it 'must have subcategories on list' do
    cat.subcategories = ['Aviation', 'Space']
    refute cat.valid?
  end

  it 'must have subcategories that correspond to category' do
    cat.subcategories = ['Aviation', 'Literature']
    refute cat.valid?
    assert_includes cat.errors[:subcategories], 'Literature is not a valid subcategory'
  end
end
