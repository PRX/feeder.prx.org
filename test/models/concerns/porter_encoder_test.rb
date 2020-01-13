require 'test_helper'

class TestEncoder
  include PorterEncoder
end

describe PorterEncoder do

  let(:sns) { SnsMock.new }
  let(:model) { TestEncoder.new }
  let(:opts) do
    {
      job_type: 'copy',
      source: 's3://src/path/key.mp3',
      destination: 's3://dest/path/key.mp3',
      callback: 'sqs://us-whatev/queue-name'
    }
  end

  around do |test|
    TestEncoder.stub :new_porter_sns_client, sns do
      test.call
    end
  end

  it 'starts a porter job' do
    account_bk, ENV['AWS_ACCOUNT_ID'] = ENV['AWS_ACCOUNT_ID'], '12345678'
    model.porter_start!(opts)
    ENV['AWS_ACCOUNT_ID'] = account_bk

    sns.message[:Job][:Id].length.must_equal 36
    sns.message[:Job][:Source].must_equal({
      'Mode' => 'AWS/S3',
      'BucketName' => 'src',
      'ObjectKey' => 'path/key.mp3'
    })
    sns.message[:Job][:Tasks].must_equal([{
      'Type' => 'Copy',
      'Mode' => 'AWS/S3',
      'BucketName' => 'dest',
      'ObjectKey' => 'path/key.mp3',
      'ContentType' => 'REPLACE',
      'Parameters' => {
        'ACL' => 'public-read',
        'CacheControl' => 'max-age=86400',
        'ContentDisposition' => 'attachment; filename="key.mp3"'
      }
    }])
    sns.message[:Job][:Inspect].must_be_nil
    sns.message[:Job][:Callbacks].must_equal([{
      'Type' => 'AWS/SQS',
      'Queue' => 'https://sqs.us-whatev.amazonaws.com/12345678/queue-name'
    }])
  end

  it 'unescapes filenames from http sources' do
    opts[:source] = 'https://some.where/the/file%252B.mp3'
    opts[:destination] = 's3://dest/path/file%252B.mp3'
    model.porter_start!(opts)

    sns.message[:Job][:Source].must_equal({
      'Mode' => 'HTTP',
      'URL' => 'https://some.where/the/file%252B.mp3'
    })
    sns.message[:Job][:Tasks].must_equal([{
      'Type' => 'Copy',
      'Mode' => 'AWS/S3',
      'BucketName' => 'dest',
      'ObjectKey' => 'path/file%2B.mp3',
      'ContentType' => 'REPLACE',
      'Parameters' => {
        'ACL' => 'public-read',
        'CacheControl' => 'max-age=86400',
        'ContentDisposition' => 'attachment; filename="file%2B.mp3"'
      }
    }])
  end

  it 'does not escape filenames from s3 sources' do
    opts[:source] = 's3://src/the/file%252B.mp3'
    opts[:destination] = 's3://dest/path/file%252B.mp3'
    model.porter_start!(opts)

    sns.message[:Job][:Source].must_equal({
      'Mode' => 'AWS/S3',
      'BucketName' => 'src',
      'ObjectKey' => 'the/file%252B.mp3'
    })
    sns.message[:Job][:Tasks].must_equal([{
      'Type' => 'Copy',
      'Mode' => 'AWS/S3',
      'BucketName' => 'dest',
      'ObjectKey' => 'path/file%252B.mp3',
      'ContentType' => 'REPLACE',
      'Parameters' => {
        'ACL' => 'public-read',
        'CacheControl' => 'max-age=86400',
        'ContentDisposition' => 'attachment; filename="file%252B.mp3"'
      }
    }])
  end

  it 'allows http sources' do
    opts[:source] = 'https://some.where/the/file.mp3'
    model.porter_start!(opts)

    sns.message[:Job][:Source].must_equal({
      'Mode' => 'HTTP',
      'URL' => 'https://some.where/the/file.mp3'
    })
  end

  it 'also inspects audio job types' do
    opts[:job_type] = 'audio'
    model.porter_start!(opts)

    sns.message[:Job][:Tasks].must_include({'Type' => 'Inspect'})
  end
end
