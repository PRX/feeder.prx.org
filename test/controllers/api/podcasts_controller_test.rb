require 'test_helper'

describe Api::PodcastsController do
  let(:podcast) { create(:podcast) }

  it 'should show' do
    get(:show, { api_version: 'v1', format: 'json', id: podcast.id } )
    assert_response :success
  end

  it 'should list' do
    podcast.id.wont_be_nil
    get(:index, { api_version: 'v1', format: 'json' } )
    assert_response :success
  end
end
