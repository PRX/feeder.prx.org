require 'test_helper'

describe PublishFeedJob do

  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }

  let(:job) { PublishFeedJob.new }

  it 'gets an aws client' do
    job.client.wont_be_nil
    job.client.must_be_instance_of Aws::S3::Client
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

  describe 'saving the rss file' do
    let (:stub_client) { Aws::S3::Client.new(stub_responses: true) }

    it 'can save a podcast file' do
      job.podcast = podcast
      job.stub(:client, stub_client) do
        rss = "<xml></xml>"
        job.save_podcast_file(rss)
      end
    end

    it 'can process publishing a podcast' do
      job.stub(:client, stub_client) do
        job.perform(podcast)
        job.rss.wont_be_nil
        job.put_object.wont_be_nil
        job.copy_object.must_be_nil
      end
    end

    it 'makes an alias copy of the podcast file' do
      podcast.feed_rss_alias = 'some-alias'
      job.stub(:client, stub_client) do
        job.perform(podcast)
        job.put_object.wont_be_nil
        job.copy_object.wont_be_nil
      end
    end
  end
end
