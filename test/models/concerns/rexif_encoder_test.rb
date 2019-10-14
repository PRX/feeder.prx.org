require 'test_helper'

class TestEncoder
  include RexifEncoder
end

describe RexifEncoder do

  let(:sns) { SnsMock.new }
  let(:model) { TestEncoder.new }
  let(:opts) do
    {
      job_type: 'audio',
      source: 's3://src/path/key.mp3',
      destination: 's3://dest/path/key.mp3',
      callback: 'sqs://us-whatev/queue-name'
    }
  end

  around do |test|
    TestEncoder.stub :new_rexif_sns_client, sns do
      test.call
    end
  end

  it 'starts a rexif job' do
    model.rexif_start!(opts)

    sns.message[:Job][:Id].length.must_equal 36
    sns.message[:Job][:Source].must_equal({
      'Mode' => 'AWS/S3',
      'BucketName' => 'src',
      'ObjectKey' => 'path/key.mp3'
    })
    sns.message[:Job][:Copy].must_equal({
      'Destinations' => [{
        'Mode' => 'AWS/S3',
        'BucketName' => 'dest',
        'ObjectKey' => 'path/key.mp3'
      }]
    })
    sns.message[:Job][:Callbacks].must_equal([{
      'Type' => 'AWS/SQS',
      'Queue' => 'https://sqs.us-whatev.amazonaws.com/561178107736/queue-name'
    }])
  end

  it 'allows http sources' do
    opts[:source] = 'https://some.where/the/file.mp3'
    model.rexif_start!(opts)

    sns.message[:Job][:Source].must_equal({
      'Mode' => 'HTTP',
      'URL' => 'https://some.where/the/file.mp3'
    })
  end
end
