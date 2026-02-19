require "test_helper"

class CopyResourceTest < ActiveSupport::TestCase
  let(:podcast) { build_stubbed(:podcast) }
  let(:episode) { build_stubbed(:episode, podcast: podcast) }
  let(:res) { build_stubbed(:stream_resource, podcast: podcast) }
  let(:uncut) { episode.build_uncut }
  let(:stub_client) { Aws::S3::Client.new(stub_responses: true) }

  around do |test|
    res.stub(:copy_resource_s3_client, stub_client) do
      test.call
    end
  end

  describe "#copy_resource_to" do
    it "skips if incomplete" do
      res.status = "processing"
      res.copy_resource_to(uncut)

      assert_nil uncut.original_url
      assert_equal 0, stub_client.api_requests.count
    end

    it "copies s3 files" do
      res.copy_resource_to(uncut)
      refute_equal "s3://prx-test-feed/#{uncut.path}", res.original_url

      assert_equal 2, stub_client.api_requests.count
      assert_equal :copy_object, stub_client.api_requests[0][:operation_name]
      assert_equal :copy_object, stub_client.api_requests[1][:operation_name]

      assert_equal "test-prx-feed", stub_client.api_requests[0][:params][:bucket]
      assert_equal uncut.path, stub_client.api_requests[0][:params][:key]
      assert_equal "/test-prx-feed/#{res.path}", stub_client.api_requests[0][:params][:copy_source]

      assert_equal "test-prx-feed", stub_client.api_requests[1][:params][:bucket]
      assert_equal uncut.waveform_path, stub_client.api_requests[1][:params][:key]
      assert_equal "/test-prx-feed/#{res.waveform_path}", stub_client.api_requests[1][:params][:copy_source]
    end

    it "copies http files" do
      stub_client.stub_responses(:copy_object, "NoSuchKey")
      stub_request(:get, res.url).to_return(status: 200, body: "the-clip")
      stub_request(:get, res.waveform_url).to_return(status: 200, body: "the-waveform")

      res.copy_resource_to(uncut)
      assert_equal res.url, uncut.original_url

      assert_equal 4, stub_client.api_requests.count
      assert_equal :copy_object, stub_client.api_requests[0][:operation_name]
      assert_equal :put_object, stub_client.api_requests[1][:operation_name]
      assert_equal :copy_object, stub_client.api_requests[2][:operation_name]
      assert_equal :put_object, stub_client.api_requests[3][:operation_name]

      assert_equal "test-prx-feed", stub_client.api_requests[1][:params][:bucket]
      assert_equal uncut.path, stub_client.api_requests[1][:params][:key]
      assert_equal "the-clip", stub_client.api_requests[1][:params][:body]

      assert_equal "test-prx-feed", stub_client.api_requests[3][:params][:bucket]
      assert_equal uncut.waveform_path, stub_client.api_requests[3][:params][:key]
      assert_equal "the-waveform", stub_client.api_requests[3][:params][:body]
    end

    it "skips waveforms if source doesn't support" do
      res.stub(:generate_waveform?, false) do
        res.copy_resource_to(uncut)

        assert_equal 1, stub_client.api_requests.count
        assert_equal :copy_object, stub_client.api_requests[0][:operation_name]
        assert_equal "/test-prx-feed/#{res.path}", stub_client.api_requests[0][:params][:copy_source]
      end
    end

    it "skips waveforms if destination doesn't support" do
      uncut.stub(:generate_waveform?, false) do
        res.copy_resource_to(uncut)

        assert_equal 1, stub_client.api_requests.count
        assert_equal :copy_object, stub_client.api_requests[0][:operation_name]
        assert_equal "/test-prx-feed/#{res.path}", stub_client.api_requests[0][:params][:copy_source]
      end
    end

    it "copies metadata" do
      res.copy_resource_to(uncut)

      assert_equal uncut.bit_rate, res.bit_rate
      assert_equal uncut.channels, res.channels
      assert_equal uncut.duration, res.duration
      assert_equal uncut.file_size, res.file_size
      assert_equal uncut.medium, res.medium
      assert_equal uncut.mime_type, res.mime_type
      assert_equal uncut.sample_rate, res.sample_rate
      assert_equal uncut.segmentation, res.segmentation
      assert_equal "complete", res.status

      refute_equal uncut.url, res.url
    end

    it "handles s3 errors" do
      stub_client.stub_responses(:copy_object, StandardError.new("Bad bad bad"))
      mock_log = Minitest::Mock.new.expect(:call, nil) { true }
      mock_notice = Minitest::Mock.new.expect(:call, nil) { true }

      Rails.logger.stub(:error, mock_log) do
        NewRelic::Agent.stub(:notice_error, mock_notice) do
          res.copy_resource_to(uncut)
          assert_equal "error", uncut.status
          assert_nil uncut.original_url
        end
      end

      mock_log.verify
      mock_notice.verify
    end

    it "handles http errors" do
      stub_client.stub_responses(:copy_object, "NoSuchKey")
      stub_request(:get, res.url).to_return(status: 404)
      mock_log = Minitest::Mock.new.expect(:call, nil) { true }
      mock_notice = Minitest::Mock.new.expect(:call, nil) { true }

      Rails.logger.stub(:error, mock_log) do
        NewRelic::Agent.stub(:notice_error, mock_notice) do
          res.copy_resource_to(uncut)
          assert_equal "error", uncut.status
          assert_nil uncut.original_url
        end
      end

      mock_log.verify
      mock_notice.verify
    end
  end
end
