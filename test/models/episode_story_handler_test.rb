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

  before {
    stub_request(:get, 'https://cms.prx.org/pub/cb424d43e437b348551eee7ac191474c/0/web/story_image/437192/original/lindsay.png').
      to_return(status: 200, body: test_file('/fixtures/transistor1400.jpg'), headers: {})
  }

  it 'can be created from a story' do
    podcast = create(:podcast, prx_uri: '/api/v1/series/36501')
    episode = EpisodeStoryHandler.create_from_story!(story)
    episode.explicit.must_equal 'clean'
    episode.wont_be_nil
    episode.published_at.wont_be_nil
    episode.published_at.must_equal Time.parse(story.attributes[:published_at])
    first_audio = episode.all_contents.first.original_url
    last_audio = episode.all_contents.last.original_url
    first_audio.must_equal 's3://mediajoint.production.prx.org/public/audio_files/1200648/lcs_spring16_act1.mp3'
    last_audio.must_equal 's3://mediajoint.production.prx.org/public/audio_files/1200657/broadcast/t01.mp3'
    episode.description.must_equal 'this is a description'
    episode.season_number.must_equal 2
    episode.episode_number.must_equal 4
  end
end
