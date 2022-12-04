require 'test_helper'

describe PublishFeedJob do

  let(:episode) { create(:episode, prx_uri: '/api/v1/stories/87683') }
  let(:podcast) { episode.podcast }
  let(:feed) { create(:feed, podcast: podcast, slug: 'adfree') }

  let(:job) { PublishFeedJob.new }

  it 'knows the right bucket to write to' do
    assert_equal job.feeder_storage_bucket, 'test-prx-feed'
    ENV['FEEDER_STORAGE_BUCKET'] = 'foo'
    assert_equal job.feeder_storage_bucket, 'foo'
    ENV['FEEDER_STORAGE_BUCKET'] = 'test-prx-feed'
  end

  it 'knows the right key to write to' do
    assert_equal job.key(podcast, podcast.default_feed), 'jjgo/feed-rss.xml'
    assert_equal job.key(podcast, feed), 'jjgo/adfree/feed-rss.xml'
  end

  describe 'saving the rss file' do
    let (:stub_client) { Aws::S3::Client.new(stub_responses: true) }

    it 'can save a podcast file' do
      job.stub(:client, stub_client) do
        refute_nil job.save_file(podcast, podcast.default_feed)
        refute_nil job.save_file(podcast, feed)
      end
    end

    it 'can process publishing a podcast' do
      job.stub(:client, stub_client) do
        rss = job.perform(podcast)
        refute_nil rss
        refute_nil job.put_object
        assert_nil job.copy_object
      end
    end
  end
end
