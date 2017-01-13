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
    first_audio = episode.all_contents.first.original_url
    last_audio = episode.all_contents.last.original_url
    first_audio.must_equal 'https://cms.prx.org/pub/e3718718a9a6c83a2cc077ee6ecb5a63/0/web/audio_file/1200648/broadcast/lcs_spring16_act1.mp3'
    last_audio.must_equal 'https://cms.prx.org/pub/8d5b5626a6ed4798fffa71e48e80fca2/0/web/audio_file/1200657/broadcast/t01.mp3'
    episode.description.must_equal 'this is a description'
  end
end
