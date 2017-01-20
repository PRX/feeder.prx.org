require 'test_helper'

describe FeedEntryUpdateJob do

  let(:job) { FeedEntryUpdateJob.new }

  before {
    stub_request(:get, 'http://serialpodcast.org/sites/all/modules/custom/serial/img/serial-itunes-logo.png').
      to_return(status: 200, body: test_file('/fixtures/transistor1400.jpg'), headers: {})
  }

  it 'handles a feed entry create and update' do
    data = json_file(:crier_entry)
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      create_episode = job.receive_feed_entry_update(data)
      create_episode.wont_be_nil

      update_episode = job.receive_feed_entry_update(data)
      update_episode.wont_be :changed?
      create_episode.must_equal update_episode
    end
  end

  it 'retries podcast update on unique constraint error' do
    data = json_file(:crier_entry)
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      episode = job.receive_feed_entry_update(data)
      created_podcast = job.podcast
      job.create_podcast
      job.podcast.must_equal created_podcast
    end
  end

  it 'retries episode update on unique constraint error' do
    data = json_file(:crier_entry)
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      episode = job.receive_feed_entry_update(data)
      created_episode = job.episode
      job.create_episode
      job.episode.must_equal created_episode
    end
  end
end
