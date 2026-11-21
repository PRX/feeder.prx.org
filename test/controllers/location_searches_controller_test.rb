require "test_helper"

class LocationSearchesControllerTest < ActionDispatch::IntegrationTest
  let(:frame) { {"Turbo-Frame" => "location-search-123"} }
  let(:austin) do
    Nominatim::Place.new(
      name: "Austin",
      display_name: "Austin, Travis County, Texas, United States",
      latitude: "30.2711286",
      longitude: "-97.7436995",
      osm: "R113314",
      country: "US"
    )
  end

  setup_current_user { build(:user, account_id: 123) }

  test "renders search results in the requesting frame" do
    search = ->(query, language:) {
      assert_equal "Austin", query
      assert_equal "en-us", language
      [austin]
    }

    Nominatim.stub(:search, search) do
      get location_search_url(q: " Austin ", language: "en-us"), headers: frame
    end

    assert_response :success
    assert_select "turbo-frame#location-search-123" do
      assert_select "button[data-action='location#select']", 1 do |buttons|
        assert_equal "Austin", buttons.first["data-location-name-param"]
        assert_equal "30.2711286", buttons.first["data-location-latitude-param"]
        assert_equal "-97.7436995", buttons.first["data-location-longitude-param"]
        assert_equal "R113314", buttons.first["data-location-osm-param"]
        assert_equal "US", buttons.first["data-location-country-param"]
      end
      assert_select "a[href='https://www.openstreetmap.org/copyright']", "OpenStreetMap"
    end
  end

  test "does not search for short queries" do
    Nominatim.stub(:search, ->(*) { flunk "should not search" }) do
      get location_search_url(q: "A"), headers: frame
    end

    assert_response :success
    assert_includes response.body, "Enter at least 2 characters"
  end

  test "renders empty results" do
    Nominatim.stub(:search, []) do
      get location_search_url(q: "Nowhere"), headers: frame
    end

    assert_includes response.body, "No places found"
  end

  test "renders busy and error messages" do
    Nominatim.stub(:search, ->(*, **) { raise Nominatim::BusyError }) do
      get location_search_url(q: "Austin"), headers: frame
    end
    assert_includes response.body, "Location search is busy"

    Nominatim.stub(:search, ->(*, **) { raise Nominatim::Error }) do
      get location_search_url(q: "Austin"), headers: frame
    end
    assert_includes response.body, "Error searching for places"
  end
end
