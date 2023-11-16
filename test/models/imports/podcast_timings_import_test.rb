require "test_helper"

describe PodcastTimingsImport do
  let(:podcast) { create(:podcast) }
  let(:import) { PodcastTimingsImport.new(podcast: podcast) }
  let(:guid_length) { Episode.generate_item_guid(podcast.id, SecureRandom.uuid).length }

  describe "#csv" do
    it "parses timings" do
      import.timings = "foo,bar"
      assert_equal [["foo", "bar"]], import.csv

      import.timings = "foo,bar\none,two"
      assert_equal [["foo", "bar"], ["one", "two"]], import.csv

      import.timings = "foo\tbar"
      assert_equal [["foo", "bar"]], import.csv
    end
  end

  describe "#default_guid_length" do
    it "returns the default guid length for this podcast" do
      # prx_1234_<uuid>
      import.podcast_id = 1234
      assert_equal 45, import.default_guid_length

      import.podcast_id = 12345678
      assert_equal 49, import.default_guid_length
    end
  end

  describe "#minimum_guid_length" do
    it "queries for the minimum episode guid length" do
      assert_equal guid_length, PodcastTimingsImport.new(podcast: podcast).minimum_guid_length

      episode = create(:episode, podcast: podcast, original_guid: "abcd")
      assert_equal 4, PodcastTimingsImport.new(podcast: podcast).minimum_guid_length

      episode.update!(original_guid: "abcd" * 20)
      assert_equal guid_length, PodcastTimingsImport.new(podcast: podcast).minimum_guid_length
    end
  end

  describe "#maximum_guid_length" do
    it "queries for the maximum episode guid length" do
      assert_equal guid_length, PodcastTimingsImport.new(podcast: podcast).maximum_guid_length

      create(:episode, podcast: podcast, original_guid: "abcd")
      assert_equal guid_length, PodcastTimingsImport.new(podcast: podcast).maximum_guid_length

      create(:episode, podcast: podcast, original_guid: "abcd" * 20)
      assert_equal 80, PodcastTimingsImport.new(podcast: podcast).maximum_guid_length
    end
  end

  describe "#has_episode_with_guid" do
    it "bounds on min guid length" do
      create(:episode, podcast: podcast, original_guid: "abcd")
      assert import.has_episode_with_guid?("abcd")
      refute import.has_episode_with_guid?("efgh")

      import.stub(:minimum_guid_length, 10) do
        refute import.has_episode_with_guid?("abcd")
        refute import.has_episode_with_guid?("efgh")
      end
    end

    it "bounds on max guid length" do
      create(:episode, podcast: podcast, original_guid: "abcd" * 20)
      assert import.has_episode_with_guid?("abcd" * 20)
      refute import.has_episode_with_guid?("efgh" * 20)

      import.stub(:maximum_guid_length, 10) do
        refute import.has_episode_with_guid?("abcd" * 20)
        refute import.has_episode_with_guid?("efgh" * 20)
      end
    end
  end

  describe "#validate_timings" do
    it "requires timings" do
      import.timings = ""
      assert import.invalid?
      assert import.errors.added? :timings, :blank
    end

    it "checks for a csv" do
      import.timings = "blah"
      assert import.invalid?
      assert import.errors.added? :timings, :not_csv
    end

    it "detects a guid column" do
      import.csv = [
        ["The Title", "The Guid", "Something Else", "Timings"],
        ["aaaa", "guid1", "whatever", "{}"],
        ["aaaa", "guid2", "whatever", "{}"],
        ["aaaa", "guid3", "whatever", "{}"],
        ["aaaa", "guid4", "whatever", "{}"]
      ]

      known_guids = ["guid1"]
      import.stub(:has_episode_with_guid?, ->(g) { known_guids.include?(g) }) do
        assert import.invalid?
        assert import.errors.added? :timings, :guid_not_found
        assert_nil import.guid_index

        # pass the 50% detection threshold
        known_guids << "guid2"
        assert import.valid?
        assert_equal 1, import.guid_index
      end
    end

    it "detects a timings column" do
      import.csv = [
        ["The Title", "The Guid", "Timings", "Something Else"],
        ["aaaa", "guid1", "whatever", "whatever"],
        ["aaaa", "guid2", "whatever", "whatever"],
        ["aaaa", "guid3", "whatever", "whatever"],
        ["aaaa", "guid4", "whatever", "whatever"]
      ]

      import.stub(:has_episode_with_guid?, true) do
        assert import.invalid?
        assert import.errors.added? :timings, :timings_not_found
        assert_nil import.timings_index

        import.csv[2][2] = "{}" # detectable as empty
        import.csv[3][2] = "99" # non-float... bad
        assert import.invalid?
        assert import.errors.added? :timings, :timings_not_found

        import.csv[4][2] = "{12.34, 56.78}" # floats are detectable
        assert import.valid?
        assert_equal 2, import.timings_index
      end
    end

    it "detects header columns" do
      import.csv = [
        ["The Title", "The Guid", "Timings", "Something Else"],
        ["aaaa", "guid1", "whatever", "{}"]
      ]

      import.stub(:has_episode_with_guid?, ->(g) { g == "guid1" }) do
        assert import.valid?
        assert_equal true, import.has_header

        import.csv = import.csv[1..]
        assert import.valid?
        assert_equal false, import.has_header
      end
    end
  end

  describe "#import!" do
    let(:import) { create(:podcast_timings_import, podcast: podcast) }
    let(:csv) do
      [
        ["The Title", "The Guid", "Timings", "Something Else"],
        ["aaaa", "guid1", "{}", "whatever"],
        ["aaaa", "guid2", "{1.23}", "whatever"],
        ["aaaa", "guid3", "4.56", "whatever"],
        ["aaaa", "guid3", "dup1", "whatever"],
        ["aaaa", "guid3", "dup2", "whatever"]
      ]
    end
    let(:job_count) { 0 }

    around do |test|
      import.stub(:has_episode_with_guid?, ->(g) { g.starts_with?("guid") }) do
        test.call
      end
    end

    it "creates episode imports" do
      import.csv = csv
      job_count = 0

      EpisodeImport.stub_any_instance(:import_later, -> { job_count += 1 }) do
        import.import!
        assert import.status_importing?

        # 5 records created
        eps = import.episode_imports.sort_by(&:id)
        assert_equal 5, eps.count
        assert_equal %w[guid1 guid2 guid3 guid3 guid3], eps.map(&:guid)
        assert_equal %w[{} {1.23} 4.56 dup1 dup2], eps.map(&:timings)
        assert_equal ["created", "created", "created", "duplicate", "duplicate"], eps.map(&:status)

        # but the 2 dups don't get jobs
        assert_equal 3, job_count
      end
    end

    it "handles errors" do
      import.csv = csv

      EpisodeImport.stub_any_instance(:import_later, -> { raise "woh!" }) do
        assert_raises(RuntimeError) { import.import! }
        assert import.status_error?
      end
    end
  end
end
