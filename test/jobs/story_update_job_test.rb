require 'test_helper'

describe StoryUpdateJob do

  let(:podcast) { create(:podcast, prx_uri: "/api/v1/series/20829") }

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

  it 'creates a story resource' do
    story = job.story_resource(JSON.parse(body))
    story.must_be_instance_of HyperResource
  end

  it 'can create an episode' do
    lbd = podcast.last_build_date
    job.receive_story_update(JSON.parse(body))
    job.episode.podcast.last_build_date.must_be :>, lbd
  end

  it 'can update an episode' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast)
    job.receive_story_update(JSON.parse(body))
    job.episode.podcast.last_build_date.must_be :>, episode.podcast.last_build_date
    job.episode.updated_at.must_be :>, episode.updated_at
  end

  it 'can delete an episode' do
    episode = create(:episode, prx_uri: '/api/v1/stories/149726', podcast: podcast)
    job.receive_story_delete(JSON.parse(body))
    job.episode.deleted_at.wont_be_nil
  end
end

