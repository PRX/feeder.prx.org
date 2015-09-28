require 'test_helper'

class FeedEntryUpdateJobTest < ActiveJob::TestCase

  let(:job) { FeedEntryUpdateJob.new }

  describe "create" do
    it 'handles a feed entry update' do
      data = json_file(:crier_entry)
      job.receive_feed_entry_update(data)
    end
  end
end
