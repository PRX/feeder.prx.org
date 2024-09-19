require "test_helper"

describe PublishPublicFeedJob do
  let(:podcast) { create(:podcast) }

  let(:job) { PublishPublicFeedJob.new }

  describe "saving the public rss file" do
    let(:stub_client) { Aws::S3::Client.new(stub_responses: true) }

    it "can call save_file on PublishFeedJob" do
      job.publish_feed_job.stub(:s3_client, stub_client) do
        refute_nil job.perform(podcast)
      end
    end
  end
end
