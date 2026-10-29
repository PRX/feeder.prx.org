require "test_helper"

describe FilteredFaradayFormatter do
  let(:log) { StringIO.new }
  let(:url) { "https://example.com/path" }

  def log_request(headers: {}, params: {})
    connection = Faraday.new(url: url, headers: headers, params: params) do |builder|
      builder.response :logger, Logger.new(log)
    end
    connection.get
  end

  before { stub_request(:get, /example.com/) }

  it "filters the Authorization header" do
    log_request(headers: {"Authorization" => "Token secret-auth"})

    _(log.string).must_include "Authorization: \"[FILTERED]\""
    _(log.string).wont_include "secret-auth"
  end

  it "filters hyphenated headers matching filter_parameters" do
    log_request(headers: {"X-Api-Key" => "secret-key", "User-Agent" => "PRX"})

    _(log.string).must_include "X-Api-Key: \"[FILTERED]\""
    _(log.string).must_include "User-Agent: \"PRX\""
    _(log.string).wont_include "secret-key"
  end

  it "filters query params matching filter_parameters" do
    log_request(params: {token: "secret-token", url: "https://feed.example.com"})

    _(log.string).must_include "token=[FILTERED]"
    _(log.string).must_include "url=https%3A%2F%2Ffeed.example.com"
    _(log.string).wont_include "secret-token"
  end
end
