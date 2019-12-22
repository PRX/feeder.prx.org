require 'test_helper'

describe PublishFeedJob do

  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }

  let(:job) { PublishFeedJob.new }

  it 'gets an aws connection' do
    job.connection.wont_be_nil
    job.connection.must_be_instance_of Aws::S3::Resource
  end

  it 'knows the right bucket to write to' do
    job.feeder_storage_bucket.must_equal 'test-prx-feed'
    ENV['FEEDER_STORAGE_BUCKET'] = 'foo'
    job.feeder_storage_bucket.must_equal 'foo'
    ENV['FEEDER_STORAGE_BUCKET'] = 'test-prx-feed'
  end

  it 'knows the right key to write to' do
    job.key(podcast).must_equal 'jjgo/feed-rss.xml'
  end

  describe 'saving the rss file' do
    let (:stub_conn) { Aws::S3::Resource.new(stub_responses: true) }

    it 'can save a podcast file' do
      job.stub(:connection, stub_conn) do
        job.save_file(podcast)
      end
    end

    it 'can process publishing a podcast' do
      job.stub(:connection, stub_conn) do
        rss = job.perform(podcast)
        rss.wont_be_nil
      end
    end
  end
end
