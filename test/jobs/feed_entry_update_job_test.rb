require 'test_helper'

class FeedEntryUpdateJobTest < ActiveJob::TestCase

  let(:job) { FeedEntryUpdateJob.new }

  describe "create" do

    before {
      stub_request(:get, "http://cdn.transistor.prx.org/wp-content/uploads/powerpress/transistor1400.jpg").
        to_return(:status => 200, :body => test_file('/fixtures/transistor1400.jpg'), :headers => {})

      stub_request(:get, "http://cdn.transistor.prx.org/wp-content/uploads/powerpress/transistor300.png").
        to_return(:status => 200, :body => test_file('/fixtures/transistor300.png'), :headers => {})
    }

    it 'handles a feed entry update' do
      data = json_file(:crier_entry)
      job.receive_feed_entry_update(data)
    end
  end
end
