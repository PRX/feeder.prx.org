# frozen_string_literal: true

require "test_helper"

describe Apple::UploadOperation do
  describe "#new" do
    it "takes in a delivery file and a operation api response fragment" do
      delivery_file = Apple::PodcastDeliveryFile.new
      operation = {"foo" => "bar"}

      upload_operation = Apple::UploadOperation.new(delivery_file: delivery_file, operation_fragment: operation)

      assert_equal delivery_file, upload_operation.delivery_file
      assert_equal operation, upload_operation.operation
    end
  end

  describe ".do_upload" do
    let(:localhost_bridge) do
      Apple::Api.new(provider_id: "asdf",
        key_id: "asdf",
        key: "asdf",
        bridge_url: "http://localhost:3000")
    end

    let(:prod_bridge) do
      Apple::Api.new(provider_id: "asdf",
        key_id: "asdf",
        key: "asdf",
        bridge_url: "http://prod-url.com")
    end

    it("should serialize when using a developmnt bridge") do
      Apple::UploadOperation.stub(:serial_upload, ["serial"]) do
        Apple::UploadOperation.stub(:parallel_upload, ["parallel"]) do
          assert_equal ["serial"], Apple::UploadOperation.do_upload(localhost_bridge, [])
          assert_equal ["parallel"], Apple::UploadOperation.do_upload(prod_bridge, [])
        end
      end
    end
  end
end
