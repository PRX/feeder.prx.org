require 'test_helper'

describe PublishFeedJob do

  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }

  let(:job) { PublishFeedJob.new }

  before {
    stub_requests_to_prx_cms
  }

  it 'gets a fog connection' do
    job.connection.wont_be_nil
    job.connection.must_be_instance_of Fog::Storage::AWS::Real
  end

  it 'knows the right bucket to write to' do
    ENV['FEEDER_STORAGE_BUCKET'] = nil
    job.feeder_storage_bucket.must_equal 'test-prx-feed'
    ENV['FEEDER_STORAGE_BUCKET'] = 'foo'
    job.feeder_storage_bucket.must_equal 'foo'
    ENV['FEEDER_STORAGE_BUCKET'] = nil
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
    job.episodes = [episode].map { |e| EpisodeBuilder.from_prx_story(e) }
    rss = job.generate_rss_xml
    rss.wont_be_nil
    rss[0, 38].must_equal '<?xml version="1.0" encoding="UTF-8"?>'
  end

  describe 'test writing file' do

    let(:local_connection) do
      opts = {
        provider: 'Local',
        local_root: File.join(Rails.root, 'tmp')
      }
      Fog::Storage.new(opts)
    end

    let(:local_file) { File.join(Rails.root, 'tmp', 'test-prx-feed', 'jjgo/feed-rss.xml') }

    before {
      FileUtils.rm_f(local_file)

    }

    it 'can save a podcast file' do
      rss = '<?xml version="1.0" encoding="UTF-8"?>'
      job.podcast = podcast
      job.stub(:connection, local_connection) do
        job.save_podcast_file(rss)
      end
      File.must_be :exists?, local_file
    end

    it 'can publish a podcast to storage' do
      job.stub(:connection, local_connection) do
        job.perform(podcast)
      end
      File.must_be :exists?, local_file
    end
  end
end
