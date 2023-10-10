require "test_helper"

describe EpisodeImport do
  let(:import) { create(:episode_import, status: "created") }
  let(:episode) { import.episode }
  let(:status_from_episodes) { Minitest::Mock.new }

  around do |test|
    import.podcast_import.stub(:status_from_episodes!, status_from_episodes) do
      test.call
    end
  end

  describe "#all_media_status" do
    it "returns the status of all episode media" do
      assert_empty import.all_media_status

      episode.build_uncut(status: "created")
      episode.images.build(status: "error")
      assert_equal ["created", "error"], import.all_media_status

      episode.contents.build(status: "processing")
      assert_equal ["processing", "created", "error"], import.all_media_status
    end
  end

  describe "#status_from_media!" do
    it "completes imports with no media" do
      assert_empty import.all_media_status
      status_from_episodes.expect(:call, nil)

      import.status_from_media!
      assert import.status_complete?
      status_from_episodes.verify
    end

    it "sets error status" do
      import.stub(:all_media_status, ["complete", "invalid", "error"]) do
        status_from_episodes.expect(:call, nil)

        import.status_from_media!
        assert import.status_error?
        status_from_episodes.verify
      end
    end

    it "sets invalid status" do
      import.stub(:all_media_status, ["complete", "processing", "invalid"]) do
        status_from_episodes.expect(:call, nil)

        import.status_from_media!
        assert import.status_invalid?
        status_from_episodes.verify
      end
    end

    it "sets processing status" do
      import.stub(:all_media_status, ["complete", "processing"]) do
        status_from_episodes.expect(:call, nil)

        import.status_from_media!
        assert import.status_importing?
        status_from_episodes.verify
      end
    end

    it "sets processing status" do
      import.stub(:all_media_status, ["complete", "complete"]) do
        status_from_episodes.expect(:call, nil)

        import.status_from_media!
        assert import.status_complete?
        status_from_episodes.verify
      end
    end
  end
end
