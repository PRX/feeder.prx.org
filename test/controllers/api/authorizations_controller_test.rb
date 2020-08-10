require 'test_helper'

describe Api::AuthorizationsController do

  let(:account_id) { '123' }
  let(:token) { StubToken.new(account_id, ['member']) }

  it 'shows the user with a valid token' do
    @controller.stub(:prx_auth_token, token) do
      get(:show, api_version: 'v1')
      assert_response :success
    end
  end

  it 'returns unauthorized with no token' do
    get(:show, api_version: 'v1')
    assert_response :unauthorized
  end
end
