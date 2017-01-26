require 'test_helper'

describe FeedEntryUpdateJob do

  let(:body) { json_file(:crier_entry) }

  let(:msg) do
    {
      message_id: 'this-is-a-message-id-guid',
      app: 'crier',
      sent_at: 1.second.ago.utc.iso8601(3),
      subject: 'feed_entry',
      action: 'update',
      body: JSON.parse(body)
    }
  end

  let(:job) { FeedEntryUpdateJob.new }

  before {
    stub_request(:get, 'http://serialpodcast.org/sites/all/modules/custom/serial/img/serial-itunes-logo.png').
      to_return(status: 200, body: test_file('/fixtures/transistor1400.jpg'), headers: {})
  }

  it 'handles a feed entry create and update' do
    data = json_file(:crier_entry)
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      create_episode = job.perform(msg)
      create_episode.wont_be_nil
      create_episode.source_updated_at.must_equal Time.parse(msg[:sent_at])

      update_episode = job.perform(msg)
      update_episode.wont_be :changed?
      create_episode.must_equal update_episode
    end
  end

  it 'retries podcast update on unique constraint error' do
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      episode = job.perform(msg)
      created_podcast = job.podcast
      created_podcast.source_updated_at.must_equal Time.parse(msg[:sent_at])

      job.create_podcast
      job.podcast.must_equal created_podcast
    end
  end

  it 'retries episode update on unique constraint error' do
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      episode = job.perform(msg)
      created_episode = job.episode
      job.create_episode
      job.episode.must_equal created_episode
    end
  end
end
