require "test_helper"

class TestUtils
  include PorterUtils
  attr_accessor :source_url
end

describe PorterUtils do
  let(:sns) { SnsMock.new }
  let(:model) { TestUtils.new }

  around do |test|
    prev_region = ENV["AWS_REGION"]
    prev_arn = ENV["PORTER_SNS_TOPIC"]

    sns.reset
    TestUtils.stub :porter_sns_client, sns do
      test.call
    end

    ENV["AWS_REGION"] = prev_region
    ENV["PORTER_SNS_TOPIC"] = prev_arn
  end

  describe ".porter_region" do
    it "parses the region from an sns topic" do
      ENV["PORTER_SNS_TOPIC"] = "arn:aws:sns:us-gov-east-1:12345678:some-topic-name"

      assert_equal "us-gov-east-1", model.class.porter_region
    end

    it "defaults to the aws region" do
      ENV["AWS_REGION"] = "eu-west-1"

      ENV["PORTER_SNS_TOPIC"] = "arn:aws:this:is:a:bad:string"
      assert_equal "eu-west-1", model.class.porter_region

      ENV["PORTER_SNS_TOPIC"] = nil
      assert_equal "eu-west-1", model.class.porter_region
    end
  end

  describe "#porter_start!" do
    it "publishes to sns" do
      model.porter_start!(any: "thing")
      assert_equal ({"Job" => {"any" => "thing"}}), sns.message
    end
  end

  describe "#porter_source" do
    it "returns s3 sources" do
      model.source_url = "s3://some/where/file.mp3"
      assert_equal "AWS/S3", model.porter_source[:Mode]
      assert_equal "some", model.porter_source[:BucketName]
      assert_equal "where/file.mp3", model.porter_source[:ObjectKey]
    end

    it "returns http sources" do
      model.source_url = "http://some/where/file.mp3"
      assert_equal "HTTP", model.porter_source[:Mode]
      assert_equal "http://some/where/file.mp3", model.porter_source[:URL]
    end

    it "throws on unknown" do
      model.source_url = "ftp://some/where/file.mp3"
      assert_raises(RuntimeError) { model.porter_source }
    end
  end

  describe "#porter_tasks" do
    it "leaves up to child classes" do
      assert_empty model.porter_tasks
    end
  end

  describe "#porter_callbacks" do
    it "returns an sqs callback" do
      assert_equal 1, model.porter_callbacks.count
      assert_equal "AWS/SQS", model.porter_callbacks[0][:Type]
      assert_equal "https://sqs.us-east-1.amazonaws.com/12345678/test_feeder_fixer_callback", model.porter_callbacks[0][:Queue]
    end
  end

  describe "#porter_escape" do
    it "does not escape s3 urls" do
      model.source_url = "s3://some/where/file.mp3"
      assert_equal "%21", model.porter_escape("%21")
    end

    it "escapes strings for http sourced urls" do
      model.source_url = "http://some/where/file.mp3"
      assert_equal "!", model.porter_escape("%21")
    end
  end
end
