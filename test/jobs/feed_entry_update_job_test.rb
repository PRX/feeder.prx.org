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
    Task.stub :new_porter_sns_client, SnsMock.new do
      create_episode = job.perform(msg)
      refute_nil create_episode
      assert_equal create_episode.source_updated_at, Time.parse(msg[:sent_at])

      update_episode = job.perform(msg)
      refute update_episode.changed?
      assert_equal create_episode, update_episode
    end
  end

  it 'retries podcast update on unique constraint error' do
    Task.stub :new_porter_sns_client, SnsMock.new do
      episode = job.perform(msg)
      created_podcast = job.podcast
      assert_equal created_podcast.source_updated_at, Time.parse(msg[:sent_at])

      job.create_podcast
      assert_equal job.podcast, created_podcast
    end
  end

  it 'retries episode update on unique constraint error' do
    Task.stub :new_porter_sns_client, SnsMock.new do
      episode = job.perform(msg)
      created_episode = job.episode
      job.create_episode
      assert_equal job.episode, created_episode
    end
  end
end
