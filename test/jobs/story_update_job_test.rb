require 'test_helper'

describe StoryUpdateJob do

  let(:podcast) { create(:podcast, prx_uri: '/api/v1/series/20829') }

  let(:job) { StoryUpdateJob.new }

  let(:body) { %{
    {
      "id": 149726,
      "publishedAt": "2015-05-18T23:12:38.000Z",
      "title": "Big Data Shows How We Live and Die",
      "_links": {
        "curies": [
          {
            "href": "http://meta.prx.org/relation/{rel}",
            "name": "prx",
            "templated": true
          }
        ],
        "prx:account": {
          "href": "/api/v1/accounts/124",
          "title": "KUFM - Montana Public Radio",
          "profile": "http://meta.prx.org/model/account/station"
        },
        "prx:series": {
            "href": "/api/v1/series/20829",
            "title": "The Write Question"
        },
        "self": {
            "href": "/api/v1/stories/149726",
            "profile": "http://meta.prx.org/model/story"
        }
      }
    }
  }}

  before do
    if use_webmock?
      stub_request(:get, 'https://cms.prx.org/api/v1/stories/149726').
        with(headers: { 'Accept' => 'application/json' } ).
        to_return(status: 200, body: body, headers: {})
    end
  end

  it 'creates a story resource' do
    story = job.api_resource(JSON.parse(body))
    story.must_be_instance_of HyperResource
  end

  it 'can create an episode' do
    mock_task = Minitest::Mock.new
    mock_task.expect(:start!, true)
    Tasks::CopyAudioTask.stub(:create!, mock_task) do
      lbd = podcast.last_build_date
      job.receive_story_update(JSON.parse(body))
      job.episode.wont_be_nil
    end
  end

  it 'can update an episode' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast)
    podcast.stub(:create_publish_task, true) do
      episode.stub(:copy_audio, true) do
        Episode.stub(:by_prx_story, episode) do
          lbd = episode.podcast.last_build_date
          uat = episode.updated_at
          job.receive_story_update(JSON.parse(body))
          job.episode.podcast.last_build_date.must_be :>, lbd
          job.episode.updated_at.must_be :>, uat
        end
      end
    end
  end

  it 'can delete an episode' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast)
    podcast.stub(:create_publish_task, true) do
      Episode.stub(:by_prx_story, episode) do
        job.receive_story_delete(JSON.parse(body))
        job.episode.deleted_at.wont_be_nil
      end
    end
  end
end
