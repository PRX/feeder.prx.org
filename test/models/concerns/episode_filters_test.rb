require "test_helper"

class EpisodeFiltersTest < ActiveSupport::TestCase
  describe ".filter_by_alias" do
    it "matches episodes without complete media" do
      episodes = [
        create(:episode, title: "No media", segment_count: nil),
        create(:episode_with_media, title: "Complete media"),
        create(:episode, title: "Missing segment", segment_count: 2).tap do |episode|
          create(:content, episode: episode, position: 1, status: "complete")
        end,
        create(:episode, title: "Processing media", segment_count: 1).tap do |episode|
          create(:content, episode: episode, position: 1, status: "processing")
        end,
        create(:episode, title: "Errored media", segment_count: 1).tap do |episode|
          create(:content, episode: episode, position: 1, status: "error")
        end,
        create(:episode, title: "Invalid media", segment_count: 1).tap do |episode|
          create(:content, episode: episode, position: 1, status: "invalid")
        end,
        create(:episode, title: "Cancelled media", segment_count: 1).tap do |episode|
          create(:content, episode: episode, position: 1, status: "cancelled")
        end,
        create(:episode, title: "Override without media", medium: "override"),
        create(:episode, title: "Complete override", medium: "override").tap do |episode|
          create(:external_media_resource, episode: episode, status: "complete")
        end,
        create(:episode, title: "Processing override", medium: "override").tap do |episode|
          create(:external_media_resource, episode: episode, status: "processing")
        end,
        create(:episode, title: "Complete uncut without contents", medium: "uncut").tap do |episode|
          create(:uncut, episode: episode, status: "complete")
        end,
        create(:episode, title: "Processing uncut", medium: "uncut").tap do |episode|
          create(:uncut, episode: episode, status: "processing")
        end
      ]

      expected_ids = episodes.select { |episode| !episode.reload.enclosure_ready?(true) }.map(&:id)
      actual_ids = Episode.where(id: episodes.map(&:id)).filter_by_alias("incomplete").pluck(:id)

      assert_equal expected_ids.sort, actual_ids.sort
    end
  end
end
