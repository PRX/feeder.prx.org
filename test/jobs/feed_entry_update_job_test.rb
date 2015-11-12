require 'test_helper'

class FeedEntryUpdateJobTest < ActiveJob::TestCase

  let(:job) { FeedEntryUpdateJob.new }

  describe "create" do

    before {
      stub_request(:get, "http://serialpodcast.org/sites/all/modules/custom/serial/img/serial-itunes-logo.png").
        to_return(:status => 200, :body => test_file('/fixtures/transistor1400.jpg'), :headers => {})
    }

    it 'handles a feed entry create and update' do
      data = json_file(:crier_entry)
      Task.stub :new_fixer_sqs_client, SqsMock.new do
        create_episode = job.receive_feed_entry_update(data)
        create_episode.wont_be_nil

        update_episode = job.receive_feed_entry_update(data)
        create_episode.must_equal update_episode
      end
    end
  end
end
