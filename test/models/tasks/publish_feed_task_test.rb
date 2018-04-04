require 'test_helper'

describe Tasks::PublishFeedTask do
  let(:task) { create(:publish_feed_task) }
  let(:content_type) { 'x-fixer-Content-Type=application%2Frss%2Bxml%3B+charset%3DUTF-8' }
  let(:cache_control) { 'x-fixer-Cache-Control=max-age%3D86400' }
  let(:query_str) { "#{content_type}&x-fixer-public=true&#{cache_control}" }

  it 'can start the job' do
    Task.stub :new_fixer_sqs_client, SqsMock.new do
      task.start!
      task.options[:source].must_equal "http://feeder.prx.org/podcasts/#{task.owner_id}"
      task.options[:destination].must_equal "s3://test-prx-feed/jjgo/feed-rss.xml?#{query_str}"
    end
  end

  it 'alias owner as podcast' do
    task.podcast.must_equal task.owner
  end

  it 'determines a destination url' do
    url = task.destination_url
    url.must_equal "s3://test-prx-feed/jjgo/feed-rss.xml?#{query_str}"
  end
end
