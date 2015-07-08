require 'test_helper'

describe Episode do
  let(:episode) { create(:episode) }

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

  it 'is ready to add to a feed' do
    episode.must_be :include_in_feed?
  end

  it 'retrieves latest copy task' do
    episode.most_recent_copy_task.wont_be_nil
  end

  it 'knows if audio is ready' do
    episode.must_be :audio_ready?
    task = Minitest::Mock.new
    task.expect(:complete?, false)
    episode.stub(:most_recent_copy_task, task) do |variable|
      episode.wont_be :audio_ready?
    end
  end
end
