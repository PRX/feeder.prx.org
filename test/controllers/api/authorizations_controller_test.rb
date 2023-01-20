require "test_helper"

describe Api::AuthorizationsController do
  let(:account_id) { "123" }
  let(:token) { StubToken.new(account_id, ["feeder:read-private"]) }

  it "shows the user with a valid token" do
    @controller.stub(:prx_auth_token, token) do
      get(:show, params: {api_version: "v1"})
      assert_response :success
    end
  end

  it "returns unauthorized with no token" do
    get(:show, params: {api_version: "v1"})
    assert_response :unauthorized
  end
end
