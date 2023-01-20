require "test_helper"

describe MediaRestrictionsValidator do
  let(:podcast) { build(:podcast) }

  it "allows blank restrictions" do
    podcast.restrictions = nil
    assert(podcast.valid?)

    podcast.restrictions = []
    assert(podcast.valid?)

    podcast.restrictions = {}
    refute(podcast.valid?)
  end

  it "validates the restriction hash" do
    bad_restrictions = [
      "",
      "string",
      ["array"],
      {},
      {type: "", relationship: ""},
      {type: "", values: ""},
      {relationship: "", values: ""}
    ]

    bad_restrictions.each do |val|
      podcast.restrictions = [val]
      refute(podcast.valid?)
      assert_includes(podcast.errors[:restrictions], "has invalid restrictions")
    end
  end

  it "validates unique restriction types" do
    podcast.restrictions = [
      {type: "country", relationship: "allow", values: ["US"]},
      {type: "country", relationship: "allow", values: ["CA"]}
    ]
    refute(podcast.valid?)
    assert_includes(podcast.errors[:restrictions], "has duplicate restriction types")
  end

  it "validates known restriction types" do
    podcast.restrictions = [{type: "something", relationship: "allow", values: ["US"]}]
    refute(podcast.valid?)
    assert_includes(podcast.errors[:restrictions], "has an unsupported restriction type")
  end

  it "validates allowed-country restrictions" do
    podcast.restrictions = [{type: "country", relationship: "deny", values: ["US"]}]
    refute(podcast.valid?)
    assert_includes(podcast.errors[:restrictions], "has an unsupported media restriction relationship")

    podcast.restrictions = [{type: "uri", relationship: "allow", values: ["https://prx.org"]}]
    refute(podcast.valid?)
    assert_includes(podcast.errors[:restrictions], "has an unsupported restriction type")

    podcast.restrictions = [{type: "country", relationship: "allow", values: []}]
    refute(podcast.valid?)
    assert_includes(podcast.errors[:restrictions], "does not have country code values")

    podcast.restrictions[0][:values] = %w[US BLAH CA]
    refute(podcast.valid?)
    assert_includes(podcast.errors[:restrictions], "has non-ISO3166 country codes")

    podcast.restrictions[0][:values] = %w[US CA]
    assert(podcast.valid?)
  end
end
