require "test_helper"

describe Nominatim do
  let(:client) { Nominatim.new }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:search_url) { "https://nominatim.openstreetmap.org/search" }
  let(:results) do
    [
      {
        "place_id" => 123,
        "osm_type" => "relation",
        "osm_id" => 113314,
        "lat" => "30.2711286",
        "lon" => "-97.7436995",
        "name" => "Austin",
        "display_name" => "Austin, Travis County, Texas, United States",
        "address" => {"city" => "Austin", "country" => "United States", "country_code" => "us"}
      },
      {
        "place_id" => 456,
        "lat" => "51.5718706",
        "lon" => "-0.7769654",
        "name" => "",
        "display_name" => "SL7 1, Marlow, England, United Kingdom",
        "address" => {"postcode" => "SL7 1", "country_code" => "gb"}
      }
    ]
  end

  around do |test|
    Rails.stub(:cache, cache) { test.call }
  end

  def stub_search(query: {}, status: 200, body: results.to_json)
    stub_request(:get, search_url)
      .with(query: hash_including({"format" => "jsonv2", "addressdetails" => "1", "limit" => "5"}.merge(query)))
      .to_return(status: status, body: body, headers: {"Content-Type" => "application/json"})
  end

  describe "#search" do
    it "maps results to places" do
      stub_search(query: {"q" => "Austin", "accept-language" => "en-us"})

      places = client.search(" Austin ", language: "en-us")
      assert_equal 2, places.length

      assert_equal "Austin", places[0].name
      assert_equal "Austin, Travis County, Texas, United States", places[0].display_name
      assert_equal "30.2711286", places[0].latitude
      assert_equal "-97.7436995", places[0].longitude
      assert_equal "R113314", places[0].osm
      assert_equal "US", places[0].country

      # postcodes have no osm object or name
      assert_equal "SL7 1", places[1].name
      assert_equal "51.5718706", places[1].latitude
      assert_equal "-0.7769654", places[1].longitude
      assert_nil places[1].osm
      assert_equal "GB", places[1].country
    end

    it "identifies the app" do
      stub = stub_search.with(headers: {"User-Agent" => Nominatim::USER_AGENT})
      client.search("Austin")
      assert_requested stub
      assert_match(/\APRX-Feeder-Location/, Nominatim::USER_AGENT)
    end

    it "uses a configured url and email" do
      stub = stub_request(:get, "https://geo.example.com/nominatim/search")
        .with(query: hash_including("q" => "Austin", "email" => "help@prx.org"))
        .to_return(status: 200, body: "[]", headers: {"Content-Type" => "application/json"})

      old_url, ENV["NOMINATIM_URL"] = ENV["NOMINATIM_URL"], "https://geo.example.com/nominatim"
      old_email, ENV["NOMINATIM_EMAIL"] = ENV["NOMINATIM_EMAIL"], "help@prx.org"
      assert_equal [], client.search("Austin")
      assert_requested stub
    ensure
      ENV["NOMINATIM_URL"] = old_url
      ENV["NOMINATIM_EMAIL"] = old_email
    end

    it "returns nothing for blank queries" do
      assert_equal [], client.search("  ")
    end

    it "caches results" do
      stub = stub_search

      client.search("Austin")
      cache.delete(Nominatim::THROTTLE_KEY)
      client.search("austin ")
      Nominatim.new.search("AUSTIN")

      assert_requested stub, times: 1
    end

    it "caches by language" do
      stub = stub_search

      client.search("Austin", language: "en")
      cache.delete(Nominatim::THROTTLE_KEY)
      client.search("Austin", language: "fr")

      assert_requested stub, times: 2
    end

    it "waits for the throttle" do
      stub = stub_search
      cache.write(Nominatim::THROTTLE_KEY, true, expires_in: 1.second)

      waited = false
      client.stub(:sleep, ->(_) {
        waited = true
        cache.delete(Nominatim::THROTTLE_KEY)
      }) do
        assert_equal 2, client.search("Austin").length
      end

      assert waited
      assert_requested stub
    end

    it "raises when still throttled" do
      stub = stub_search
      cache.write(Nominatim::THROTTLE_KEY, true, expires_in: 1.minute)

      client.stub(:sleep, nil) do
        assert_raises(Nominatim::BusyError) { client.search("Austin") }
      end

      assert_not_requested stub
    end

    it "raises on http errors without caching" do
      stub_search(status: 500, body: "oops")
      assert_raises(Nominatim::Error) { client.search("Austin") }

      cache.delete(Nominatim::THROTTLE_KEY)
      stub_search
      assert_equal 2, client.search("Austin").length
    end
  end
end
