require "test_helper"

describe Location do
  let(:austin) { build(:location) }

  describe "#valid?" do
    it "requires a name of 128 characters or less" do
      assert austin.valid?

      austin.name = nil
      refute austin.valid?

      austin.name = "a" * 129
      refute austin.valid?

      austin.name = "a" * 128
      assert austin.valid?
    end

    it "requires a rel" do
      austin.rel = nil
      refute austin.valid?

      austin.rel = "subject"
      assert austin.valid?

      assert_raises(ArgumentError) { austin.rel = "elsewhere" }
    end

    it "validates coordinates" do
      austin.latitude = 90.1
      refute austin.valid?

      austin.latitude = -90
      austin.longitude = 180.1
      refute austin.valid?

      austin.longitude = -180
      assert austin.valid?
    end

    it "requires both or neither coordinate" do
      austin.latitude = nil
      refute austin.valid?

      austin.longitude = nil
      assert austin.valid?
    end

    it "validates osm ids" do
      ["R113314", "W5013364", "N1710195942", "R7444#188", nil].each do |osm|
        austin.osm = osm
        assert austin.valid?, "expected #{osm} to be valid"
      end

      ["113314", "relation113314", "X123", "R", "r113314"].each do |osm|
        austin.osm = osm
        refute austin.valid?, "expected #{osm} to be invalid"
      end
    end

    it "validates and normalizes country codes" do
      austin.country = " us "
      assert austin.valid?
      assert_equal "US", austin.country

      austin.country = "USA"
      refute austin.valid?
    end

    it "allows name-only locations" do
      hogwarts = build(:location, name: "Hogwarts", rel: "subject", latitude: nil, longitude: nil, osm: nil, country: nil)
      assert hogwarts.valid?
    end
  end

  describe "#geo" do
    it "combines coordinates into a geo uri" do
      assert_equal "geo:30.2711286,-97.7436995", austin.geo

      austin.latitude = 38.8881
      austin.longitude = -77.026
      assert_equal "geo:38.8881,-77.026", austin.geo

      austin.longitude = nil
      assert_nil austin.geo
    end

    it "parses geo uris into coordinates" do
      ["geo:30.27,-97.74", "geo:30.27,-97.74,250", "geo:30.27,-97.74;u=3900000"].each do |geo|
        austin.geo = geo
        assert_equal [30.27, -97.74], [austin.latitude, austin.longitude], "expected #{geo} to parse"
      end

      ["30.27,-97.74", "geo:30.27", "geo:abc,def", "geo:30.27,-97.74;u", nil].each do |geo|
        austin.geo = geo
        assert_nil austin.latitude, "expected #{geo} not to parse"
        assert_nil austin.longitude, "expected #{geo} not to parse"
      end
    end
  end

  describe ".osm_url" do
    it "defaults to openstreetmap.org" do
      assert_equal "https://www.openstreetmap.org", Location.osm_url
      assert_equal "https://www.openstreetmap.org/copyright", Location.osm_url("copyright")
    end

    it "can be configured" do
      prev = ENV["OSM_URL"]
      ENV["OSM_URL"] = "https://osm.example.com/"
      assert_equal "https://osm.example.com", Location.osm_url
      assert_equal "https://osm.example.com/node/1", build(:location, osm: "N1").osm_url
    ensure
      ENV["OSM_URL"] = prev
    end
  end

  describe "#osm_url" do
    it "links to the openstreetmap object" do
      assert_equal "https://www.openstreetmap.org/relation/113314", austin.osm_url
      assert_equal "https://www.openstreetmap.org/way/5013364", build(:location, osm: "W5013364").osm_url
      assert_equal "https://www.openstreetmap.org/node/1", build(:location, osm: "N1").osm_url
      assert_equal "https://www.openstreetmap.org/relation/7444", build(:location, osm: "R7444#188").osm_url
    end

    it "is nil without a valid osm id" do
      assert_nil build(:location, osm: nil).osm_url
      assert_nil build(:location, osm: "bad").osm_url
    end
  end

  it "touches the owner" do
    austin.save!
    podcast = austin.owner
    updated_at = podcast.reload.updated_at

    travel 1.minute do
      austin.update!(name: "Austin, TX")
      assert podcast.reload.updated_at > updated_at
    end
  end
end
