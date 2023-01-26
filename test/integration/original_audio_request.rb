require "test_helper"
require "nokogiri"

describe "Get Original Audio Integration Test" do
  it "requests the original audio for a story audio file" do
    Dotenv.load
    client_id = ENV["PRX_CLIENT_ID"]
    client_secret = ENV["PRX_SECRET"]
    oauth_options = {site: "http://id.prx.dev", token_url: "/token"}

    client = OAuth2::Client.new(client_id, client_secret, oauth_options) do |faraday|
      faraday.request :url_encoded
      faraday.response :logger
      faraday.adapter :excon
    end

    token = client.client_credentials.get_token(account: 125347).token

    require "json/jwt"
    JSON::JWT.decode(token, :skip_verification)

    api = HyperResource.new(
      root: "http://cms.prx.dev/api/v1",
      headers: {"Authorization" => "Bearer #{token}"}
    )

    api.href = "/api/v1/stories/80548"
    story = api.get

    original = story.audio[0].original(expiration: 6000).get_response
    location = original.headers["location"]

    refute_nil(location)
  end
end
