require 'test_helper'
require 'prx_access'

describe PodcastSeriesHandler do
  include PRXAccess

  let(:podcast) { create(:podcast) }

  let(:series) do
    msg = json_file(:prx_series)
    body = JSON.parse(msg)
    href = body['_links']['self']['href']
    resource = PRXAccess::PRXHyperResource.new(root: 'https://cms.prx.org/api/vi/')
    link = PRXAccess::PRXHyperResource::Link.new(resource, href: href)
    PRXAccess::PRXHyperResource.new_from(body: body, resource: resource, link: link)
  end

  it 'can be created from a series' do
    podcast = PodcastSeriesHandler.create_from_series!(series)
    podcast.wont_be_nil
    podcast.published_at.wont_be_nil
    podcast.description.must_match /^Brought to you by PRX/
  end
end
