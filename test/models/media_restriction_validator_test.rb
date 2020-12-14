require 'test_helper'

describe MediaRestrictionValidator do
  let(:podcast) { build(:podcast) }

  it 'allows nil restriction' do
    podcast.restriction.must_be_nil
    podcast.must_be :valid?
  end

  it 'validates the restriction hash' do
    bad_restrictions = [
      '',
      'string',
      ['array'],
      {},
      { type: '', relationship: '' },
      { type: '', values: '' },
      { relationship: '', values: '' }
    ]

    bad_restrictions.each do |val|
      podcast.restriction = val
      podcast.wont_be :valid?
      podcast.errors[:restriction].must_include 'is not a valid media restriction'
    end
  end

  it 'validates allowed-country restrictions only' do
    podcast.restriction = { type: 'country', relationship: 'deny', values: ['US'] }
    podcast.wont_be :valid?
    podcast.errors[:restriction].must_include 'is not an allowed-country restriction'

    podcast.restriction = { type: 'uri', relationship: 'allow', values: ['https://prx.org'] }
    podcast.wont_be :valid?
    podcast.errors[:restriction].must_include 'is not an allowed-country restriction'
  end

  it 'validates country codes' do
    podcast.restriction = { type: 'country', relationship: 'allow', values: [] }
    podcast.wont_be :valid?
    podcast.errors[:restriction].must_include 'does not have country code values'

    podcast.restriction[:values] = %w(US BLAH CA)
    podcast.wont_be :valid?
    podcast.errors[:restriction].must_include 'has non-ISO3166 country codes'

    podcast.restriction[:values] = %w(US CA)
    podcast.must_be :valid?
  end
end
