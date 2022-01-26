require 'test_helper'

describe PublishFeedJob do

  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }

  let(:job) { PublishFeedJob.new }

  it 'gets an aws client' do
    refute_nil job.client
    assert_instance_of Aws::S3::Client, job.client
  end

  it 'knows the right bucket to write to' do
    assert_equal job.feeder_storage_bucket, 'test-prx-feed'
    ENV['FEEDER_STORAGE_BUCKET'] = 'foo'
    assert_equal job.feeder_storage_bucket, 'foo'
    ENV['FEEDER_STORAGE_BUCKET'] = 'test-prx-feed'
  end

  it 'knows the right key to write to' do
    assert_equal job.key(podcast), 'jjgo/feed-rss.xml'
  end

  it 'can load the rss template' do
    refute_nil job.rss_template
    assert_equal job.rss_template[0,12], 'xml.instruct'
  end

  it 'can setup the data based on the podcast' do
    job.setup_data(podcast)
    assert_equal job.podcast, podcast
    assert_equal job.episodes.count, 1
  end

  it 'can setup the data based on the podcast' do
    job.podcast = podcast
    job.episodes = podcast.feed_episodes
    rss = job.generate_rss_xml
    refute_nil rss
    assert_equal rss[0, 38], '<?xml version="1.0" encoding="UTF-8"?>'
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
        refute_nil job.rss
        refute_nil job.put_object
        assert_nil job.copy_object
      end
    end

    it 'makes an alias copy of the podcast file' do
      podcast.default_feed.file_name = 'some-alias'
      job.stub(:client, stub_client) do
        job.perform(podcast)
        refute_nil job.put_object
        refute_nil job.copy_object
      end
    end
  end
end
