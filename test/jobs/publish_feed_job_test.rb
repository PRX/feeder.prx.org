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

  it 'can load the rss template' do
    job.rss_template.wont_be_nil
    job.rss_template[0,12].must_equal 'xml.instruct'
  end

  it 'can setup the data based on the podcast' do
    job.setup_data(podcast)
    job.podcast.must_equal podcast
    job.episodes.count.must_equal 1
  end

  it 'can setup the data based on the podcast' do
    job.podcast = podcast
    job.episodes = podcast.feed_episodes
    rss = job.generate_rss_xml
    rss.wont_be_nil
    rss[0, 38].must_equal '<?xml version="1.0" encoding="UTF-8"?>'
  end

  describe 'test writing file' do
    it 'can save a podcast file' do
      raise "finish this"
    end
  end
end
