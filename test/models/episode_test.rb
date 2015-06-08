require 'test_helper'

describe Episode do
  it 'must belong to a podcast' do
    episode = build_stubbed(:episode)
    episode.must_be(:valid?)
    episode.must_respond_to(:podcast)

    episode = build_stubbed(:episode, podcast: nil)
    episode.wont_be(:valid?)
  end

  it 'sets the guid on save' do
    episode = build(:episode, guid: nil)
    episode.guid.must_be_nil
    episode.save
    episode.guid.wont_be_nil
  end
end
