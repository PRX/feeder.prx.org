require 'test_helper'

describe Authorization do
  let(:account_id) { '123' }
  let(:token) { StubToken.new(account_id, ['member'], 456) }
  let(:authorization) { Authorization.new(token) }
  let(:podcast1) { create(:podcast, prx_account_uri: "/api/v1/accounts/#{account_id}", path: 'pod1') }
  let(:podcast2) { create(:podcast, prx_account_uri: "/api/v1/accounts/987", path: 'pod2') }
  let(:podcast3) { create(:podcast, prx_account_uri: "/api/v1/accounts/654", path: 'pod3') }

  it 'has a user_id' do
    authorization.user_id.must_equal 456
  end


  it 'has a token' do
    authorization.token.wont_be_nil
  end

  it 'has a cache_key' do
    authorization.cache_key.wont_be_nil
    authorization.cache_key.must_match /PRX::Authorization/
  end

  it 'has token accounts' do
    authorization.token_auth_account_ids.must_equal ['123']
    authorization.token_auth_account_uris.must_equal ['/api/v1/accounts/123']
  end

  it 'gets podcasts for token accounts' do
    podcast1 && podcast2 && podcast3
    authorization.token_auth_podcasts.count.must_equal 1
    authorization.token_auth_podcasts.first.must_equal podcast1
  end
end
