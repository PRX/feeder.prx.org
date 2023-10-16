require "test_helper"

describe PodcastImport do
  let(:import) { create(:podcast_import, status: "created") }
  let(:podcast) { import.podcast }

  describe "#status_from_episodes!" do
    it "completes imports with no episodes" do
      assert_empty import.episode_imports

      import.status_from_episodes!
      assert import.status_complete?
    end

    it "sets statuses" do
      import.episode_imports.create(status: "complete")
      import.status_from_episodes!
      assert import.status_complete?

      import.episode_imports.create(status: "error")
      import.status_from_episodes!
      assert import.status_error?

      import.episode_imports.create(status: "started")
      import.status_from_episodes!
      assert import.status_importing?
    end

    it "unlocks the podcast when done" do
      podcast.update(locked: true)
      import.episode_imports.create(status: "importing")

      import.status_from_episodes!
      assert import.undone?
      assert podcast.reload.locked?

      import.episode_imports.first.update(status: "error")

      import.status_from_episodes!
      assert import.done?
      refute podcast.reload.locked?
    end
  end
end
