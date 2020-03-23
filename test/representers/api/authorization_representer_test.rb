require 'test_helper'

describe Api::AuthorizationRepresenter do

  let(:account_id) { '123' }
  let(:token) { StubToken.new(account_id, ['member'], 456) }
  let(:authorization) { Authorization.new(token) }
  let(:representer) { Api::AuthorizationRepresenter.new(authorization) }
  let(:podcast) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}") }
  let(:episode) { create(:episode, podcast: podcast) }
  let(:json) { JSON.parse(representer.to_json) }

  it 'has link to episodes' do
    episode.id.wont_be_nil
    json['_links']['prx:episodes'].wont_be_nil
    json['_links']['prx:episodes']['count'].must_equal 1
  end

  it 'has link to episode' do
    json['_links']['prx:episode'].wont_be_nil
  end

  it 'has link to podcasts' do
    podcast.id.wont_be_nil
    json['_links']['prx:podcasts'].wont_be_nil
    json['_links']['prx:podcasts']['count'].must_equal 1
  end

  it 'has link to podcast' do
    json['_links']['prx:podcast'].wont_be_nil
  end
end
