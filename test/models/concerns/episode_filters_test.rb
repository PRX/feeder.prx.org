require "test_helper"

class EpisodeFiltersTest < ActiveSupport::TestCase
  describe ".filter_by_alias" do
    it "includes episodes with no content media" do
      incomplete = create(:episode, title: "Favourite needs media", published_at: 1.day.ago, segment_count: nil)
      create(:episode_with_media, title: "Favourite complete media", published_at: 1.day.ago)
      create(:episode, title: "No matching title", published_at: 1.day.ago, segment_count: nil)

      actual_ids = Episode.published.filter_by_title("Favourite").filter_by_alias("incomplete").pluck(:id)

      assert_equal [incomplete.id], actual_ids
    end
  end
end
