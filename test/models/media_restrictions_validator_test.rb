require 'test_helper'

describe MediaRestrictionsValidator do
  let(:podcast) { build(:podcast) }

  it 'allows blank restrictions' do
    podcast.restrictions = nil
    podcast.must_be :valid?

    podcast.restrictions = []
    podcast.must_be :valid?

    podcast.restrictions = {}
    podcast.wont_be :valid?
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
      podcast.restrictions = [val]
      podcast.wont_be :valid?
      podcast.errors[:restrictions].must_include 'has invalid restrictions'
    end
  end

  it 'validates unique restriction types' do
    podcast.restrictions = [
      { type: 'country', relationship: 'allow', values: ['US'] },
      { type: 'country', relationship: 'allow', values: ['CA'] }
    ]
    podcast.wont_be :valid?
    podcast.errors[:restrictions].must_include 'has duplicate restriction types'
  end

  it 'validates known restriction types' do
    podcast.restrictions = [{ type: 'something', relationship: 'allow', values: ['US'] }]
    podcast.wont_be :valid?
    podcast.errors[:restrictions].must_include 'has an unsupported restriction type'
  end

  it 'validates allowed-country restrictions' do
    podcast.restrictions = [{ type: 'country', relationship: 'deny', values: ['US'] }]
    podcast.wont_be :valid?
    podcast.errors[:restrictions].must_include 'has an unsupported media restriction relationship'

    podcast.restrictions = [{ type: 'uri', relationship: 'allow', values: ['https://prx.org'] }]
    podcast.wont_be :valid?
    podcast.errors[:restrictions].must_include 'has an unsupported restriction type'

    podcast.restrictions = [{ type: 'country', relationship: 'allow', values: [] }]
    podcast.wont_be :valid?
    podcast.errors[:restrictions].must_include 'does not have country code values'

    podcast.restrictions[0][:values] = %w(US BLAH CA)
    podcast.wont_be :valid?
    podcast.errors[:restrictions].must_include 'has non-ISO3166 country codes'

    podcast.restrictions[0][:values] = %w(US CA)
    podcast.must_be :valid?
  end
end
