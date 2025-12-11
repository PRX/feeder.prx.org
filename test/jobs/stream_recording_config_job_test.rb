require "test_helper"

describe StreamRecordingConfigJob do
  let(:stub_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:job) { StreamRecordingConfigJob.new }

  around do |test|
    job.stub(:s3_client, stub_client) do
      test.call
    end
  end

  describe "#perform" do
    it "saves the config to s3" do
      s1 = create(:stream_recording)
      job.perform

      assert_equal 1, stub_client.api_requests.count
      assert_equal "test-prx-feed", stub_client.api_requests[0][:params][:bucket]
      assert_equal "streams.json", stub_client.api_requests[0][:params][:key]
      assert_equal "max-age=60", stub_client.api_requests[0][:params][:cache_control]
      assert_equal "application/json", stub_client.api_requests[0][:params][:content_type]
      assert_equal s1.id, JSON.parse(stub_client.api_requests[0][:params][:body])[0]["id"]
    end
  end
end
