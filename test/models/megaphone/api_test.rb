require "test_helper"
require "securerandom"

describe Megaphone::Api do
  let(:token) { SecureRandom.uuid }
  let(:network_id) { "this-is-a-network-id" }
  let(:organization_id) { "this-is-an-organization-id" }
  let(:api) { Megaphone::Api.new(token: token, network_id: network_id, organization_id: organization_id) }

  it "assigns the attributes" do
    assert_equal api.token, token
    assert_equal api.network_id, network_id
    assert_equal api.organization_id, organization_id
  end
end
