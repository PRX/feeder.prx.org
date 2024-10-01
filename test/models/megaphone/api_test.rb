require "test_helper"
require "securerandom"

describe Megaphone::Api do

  let(:token) { SecureRandom.uuid }
  let(:network_id) { "this-is-a-network-id" }
  let(:api) { Megaphone::Api.new(token: token, network_id: network_id) }

  it "assigns the api key" do
    assert_equal api.token, token
  end
end
