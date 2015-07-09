require 'test_helper'

describe Episode do
  let(:episode) { create(:episode) }

  let(:msg) do
    %{
      {
        "_links": {
          "curies": [{
            "name": "prx",
            "href": "http://meta.prx.org/relation/{rel}",
            "templated": true
          }],
          "self": {
            "href": "/api/v1/stories/80548",
            "profile": "http://meta.prx.org/model/story"
          },
          "prx:account": {
            "href": "/api/v1/accounts/125347",
            "title": "American Routes",
            "profile": "http://meta.prx.org/model/account/group"
          },
          "prx:series": {
            "href": "/api/v1/series/32166",
            "title": "American Routes"
          },
          "prx:audio": {
            "href": "/api/v1/stories/80548/audio_files",
            "count": 2
          }
        }
      }
    }
  end

  let(:story) do
    body = JSON.parse(msg)
    href = body['_links']['self']['href']
    resource = HyperResource.new(root: 'https://cms.prx.org/api/vi/')
    link = HyperResource::Link.new(resource, href: href)
    HyperResource.new_from(body: body, resource: resource, link: link)
  end

  it 'can be created from a story' do
    podcast = create(:podcast, prx_uri: '/api/v1/series/32166')
    episode = Episode.create_from_story!(story)
    episode.wont_be_nil
  end

  it 'can be found by story' do
    create(:episode, prx_uri: '/api/v1/stories/80548')
    episode = Episode.by_prx_story(story)
    episode.wont_be_nil
  end

  it 'must belong to a podcast' do
    episode = build_stubbed(:episode)
    episode.must_be(:valid?)
    episode.must_respond_to(:podcast)

    episode = build_stubbed(:episode, podcast: nil)
    episode.wont_be(:valid?)
  end

  it 'sets the guid on save' do
    episode = build(:episode, guid: nil)
    episode.guid.must_be_nil
    episode.save
    episode.guid.wont_be_nil
  end

  it 'is ready to add to a feed' do
    episode.must_be :include_in_feed?
  end

  it 'retrieves latest copy task' do
    episode.most_recent_copy_task.wont_be_nil
  end

  it 'knows if audio is ready' do
    episode.must_be :audio_ready?
    task = Minitest::Mock.new
    task.expect(:complete?, false)
    episode.stub(:most_recent_copy_task, task) do |variable|
      episode.wont_be :audio_ready?
    end
  end
end
