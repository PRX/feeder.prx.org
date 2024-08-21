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

    it "unlocks the podcast later when done" do
      podcast.update(locked: true)
      refute_nil podcast.locked_until
      import.episode_imports.create(status: "importing")

      import.status_from_episodes!
      assert import.undone?
      assert podcast.reload.locked?

      import.episode_imports.first.update(status: "error")

      import.status_from_episodes!
      assert import.done?
      assert podcast.reload.locked?
      assert podcast.locked_until > Time.now
      assert podcast.locked_until < 2.minutes.from_now
    end
  end

  describe "#unlock_podcast_later!" do
    it "keeps imports with lots of episodes locked for awhile" do
      podcast.update(locked: true)
      assert podcast.locked_until > "2999-01-01".to_date

      import.stub(:episode_imports, 78.times) do
        import.unlock_podcast_later!
        assert podcast.locked_until > Time.now
        assert podcast.locked_until < 2.minutes.from_now
      end

      import.stub(:episode_imports, 3000.times) do
        import.unlock_podcast_later!
        assert podcast.locked_until > 15.minutes.from_now
        assert podcast.locked_until < 45.minutes.from_now
      end
    end
  end
end
