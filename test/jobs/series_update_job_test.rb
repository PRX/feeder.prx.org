require 'test_helper'

describe SeriesUpdateJob do

  let(:podcast) { create(:podcast, prx_uri: '/api/v1/series/20829') }

  let(:job) { SeriesUpdateJob.new }

  let(:body) { json_file(:prx_series) }

  let(:profile) { 'https://cms-staging.prx.tech/pub/d754c711890d7b7a57a43a432dd79137/0/web/series_image/15407/original/mothradiohr-whitelogo.jpg' }

  before {
    stub_request(:get, profile).
      to_return(status: 200, body: test_file('/fixtures/transistor1400.jpg'), headers: {})
  }

  before do
    if use_webmock?
      stub_request(:get, 'https://cms.prx.org/api/v1/series/149726').
        with(headers: { 'Accept' => 'application/json' } ).
        to_return(status: 200, body: body, headers: {})
    end
  end

  it 'creates a series resource' do
    series = job.api_resource(JSON.parse(body).with_indifferent_access)
    series.must_be_instance_of PRXAccess::PRXHyperResource
  end

  it 'can create an podcast' do
    podcast.wont_be_nil
    mock_podcast = Minitest::Mock.new
    mock_podcast.expect(:copy_media, true)
    mock_podcast.expect(:podcast, podcast)
    PodcastSeriesHandler.stub(:create_from_series!, mock_podcast) do
      podcast.stub(:create_publish_task, true) do
        job.perform(subject: 'series', action: 'update', body: JSON.parse(body))
      end
    end
  end

  it 'can update an podcast' do
    series = JSON.parse(body)
    series['updated_at'] = 1.second.since.utc.rfc2822
    podcast.stub(:create_publish_task, true) do
      Podcast.stub(:by_prx_series, podcast) do
        lbd = podcast.last_build_date
        uat = podcast.updated_at
        job.perform(subject: 'series', action: 'update', body: series)
        job.podcast.last_build_date.must_be :>, lbd
        job.podcast.updated_at.must_be :>, uat
      end
    end
  end

  it 'can update a deleted podcast' do
    series = JSON.parse(body)
    series['updated_at'] = 1.second.since.utc.rfc2822
    podcast = create(:podcast, prx_uri: '/api/v1/series/32832', deleted_at: Time.now)
    podcast.must_be :deleted?
    podcast.stub(:create_publish_task, true) do
      Podcast.stub(:by_prx_series, podcast) do
        job.perform(subject: 'series', action: 'update', body: series)
        job.podcast.wont_be :deleted?
      end
    end
  end

  it 'can delete an podcast' do
    podcast = create(:podcast, prx_uri: '/api/v1/series/32832')
    podcast.stub(:create_publish_task, true) do
      Podcast.stub(:by_prx_series, podcast) do
        job.perform(subject: 'series', action: 'delete', body: JSON.parse(body))
        job.podcast.deleted_at.wont_be_nil
      end
    end
  end
end
