require "test_helper"

describe Prx::Augury do
  let(:augury) { Prx::Augury.new }

  before {
    stub_request(:post, "https://#{ENV["ID_HOST"]}/token")
      .to_return(status: 200,
        body: '{"access_token":"thisisnotatoken","token_type":"bearer"}'.freeze,
        headers: {"Content-Type" => "application/json; charset=utf-8"})

    stub_request(:get, "https://#{ENV["AUGURY_HOST"]}/api/v1/podcasts/1234/placements")
      .to_return(status: 200, body: json_file(:placements), headers: {})
  }

  it "retrieves placements" do
    placements = augury.placements(1234)
    assert placements.collect { |p| p.original_count } == [1, 2, 3]
  end
end
