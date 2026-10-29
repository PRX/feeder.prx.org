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

  it "filters the Authorization header from logs" do
    stub_request(:get, "https://cms.megaphone.fm/api/networks/#{network_id}/podcasts")
      .to_return(status: 200, body: "[]", headers: {})
    log = StringIO.new

    Rails.stub(:logger, Logger.new(log)) do
      api.get("podcasts")
    end

    _(log.string).must_include "Authorization: \"[FILTERED]\""
    _(log.string).wont_include token
  end
end
