require 'test_helper'
require 'prx_access'

describe EpisodeStoryHandler do
  include PRXAccess

  let(:episode) { create(:episode) }

  let(:story) do
    msg = json_file(:prx_story_all)
    body = JSON.parse(msg)
    href = body['_links']['self']['href']
    resource = PRXAccess::PRXHyperResource.new(root: 'https://cms.prx.org/api/vi/')
    link = PRXAccess::PRXHyperResource::Link.new(resource, href: href)
    PRXAccess::PRXHyperResource.new_from(body: body, resource: resource, link: link)
  end

  it 'can be created from a story' do
    podcast = create(:podcast, prx_uri: '/api/v1/series/36501')
    episode = EpisodeStoryHandler.create_from_story!(story)
    episode.wont_be_nil
    episode.published_at.wont_be_nil
    episode.published_at.must_equal Time.parse(story.attributes[:published_at])
  end
end
