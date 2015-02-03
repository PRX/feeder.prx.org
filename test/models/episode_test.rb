require 'test_helper'

describe Episode do
  it 'must belong to a podcast' do
    episode = build_stubbed(:episode)
    episode.must_be(:valid?)
    episode.must_respond_to(:podcast)

    episode = build_stubbed(:episode, podcast: nil)
    episode.wont_be(:valid?)
  end

  it 'must soft delete' do
    episode = create(:episode)

    episode.destroy

    Episode.only_deleted.must_include episode
    Episode.all.wont_include episode
  end

  it 'must really delete' do
    episode = create(:episode)

    episode.destroy!

    Episode.with_deleted.wont_include episode
  end
end
