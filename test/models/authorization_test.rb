require 'test_helper'

describe Authorization do
  let(:account_id) { '123' }
  let(:token) { StubToken.new(account_id, ['member'], 456) }
  let(:authorization) { Authorization.new(token) }

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
end
