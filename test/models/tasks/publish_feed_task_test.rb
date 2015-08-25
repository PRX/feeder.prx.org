require 'test_helper'

describe Tasks::PublishFeedTask do
  let(:task) { create(:publish_feed_task) }

  it 'can start the job' do
    task.fixer_sqs_client = SqsMock.new
    task.start!
    task.options[:source].must_equal "http://feeder.prx.org/podcasts/#{task.owner_id}"
    task.options[:destination].must_equal 's3://test-prx-feed/jjgo/feed-rss.xml?x-fixer-public=true&x-fixer-Content-Type=text%2Fxml%3B+charset%3DUTF-8'
  end

  it 'alias owner as podcast' do
    task.podcast.must_equal task.owner
  end

  it 'determines a destination url' do
    url = task.destination_url
    url.must_equal 's3://test-prx-feed/jjgo/feed-rss.xml?x-fixer-public=true&x-fixer-Content-Type=text%2Fxml%3B+charset%3DUTF-8'
  end
end
