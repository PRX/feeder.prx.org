require 'test_helper'

describe Episode do
  it 'must belong to a podcast' do
    episode = build_stubbed(:episode)
    episode.must_be(:valid?)
    episode.must_respond_to(:podcast)

    episode = build_stubbed(:episode, podcast: nil)
    episode.wont_be(:valid?)
  end

  it 'must have a title' do
    build_stubbed(:episode, title: nil).wont_be(:valid?)
  end

  it 'must have a description' do
    build_stubbed(:episode, description: nil).wont_be(:valid?)
  end

  it 'must have an audio file' do
    build_stubbed(:episode, audio_file: nil).wont_be(:valid?)
  end

  it 'must have an author' do
    build_stubbed(:episode, author: nil).wont_be(:valid?)
  end

  it 'must have a duration' do
    build_stubbed(:episode, duration: nil).wont_be(:valid?)
  end

  it 'can have a comments link' do
    build_stubbed(:episode, comments: nil).must_be(:valid?)
  end

  it 'can have a subtitle' do
    build_stubbed(:episode, subtitle: nil).must_be(:valid?)
  end

  it 'can have a summary' do
    build_stubbed(:episode, summary: nil).must_be(:valid?)
  end

  it 'can have keywords' do
    build_stubbed(:episode, keywords: nil).must_be(:valid?)
  end

  it 'can have categories' do
    build_stubbed(:episode, categories: nil).must_be(:valid?)
  end
end
