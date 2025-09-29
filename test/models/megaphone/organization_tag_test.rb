require "test_helper"

describe Megaphone::OrganizationTag do
  let(:podcast) { create(:podcast, id: 1234) }
  let(:public_feed) { podcast.default_feed }
  let(:feed) { create(:megaphone_feed, podcast: podcast, private: true) }
  let(:tags_json) do
    {
      items: [
        {
          label: "tag 1",
          value: "tag_1",
          podcastCount: 2,
          episodeCount: 0
        }
      ]
    }.to_json
  end

  it "can retrieve the organization tags" do
    stub_request(:get, "https://cms.megaphone.fm/api/organizations/this-is-an-organization-id/tags")
      .to_return(status: 200, body: tags_json, headers: {})

    tags = Megaphone::OrganizationTag.list_by_feed(feed)
    assert_equal 1, tags.size
    assert_equal "tag 1", tags.first.label
    assert_equal "tag_1", tags.first.value
    assert_equal 2, tags.first.podcast_count
    assert_equal 0, tags.first.episode_count
  end
end
