require "test_helper"

describe Api::AuthorizationRepresenter do
  let(:account_id) { "123" }
  let(:token) { StubToken.new(account_id, ["feeder:read-private"], 456) }
  let(:authorization) { Authorization.new(token) }
  let(:representer) { Api::AuthorizationRepresenter.new(authorization) }
  let(:json) { JSON.parse(representer.to_json) }

  it "has link to episodes" do
    refute_nil json["_links"]["prx:episodes"]
  end

  it "has link to episode" do
    refute_nil json["_links"]["prx:episode"]
  end

  it "has link to podcasts" do
    refute_nil json["_links"]["prx:podcasts"]
  end

  it "has link to podcast" do
    refute_nil json["_links"]["prx:podcast"]
  end
end
