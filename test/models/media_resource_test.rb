require "test_helper"

describe MediaResource do
  let(:episode) { media_resource.episode }
  let(:media_resource) { create(:media_resource, task_count: 0) }

  it "initializes attributes" do
    mr = MediaResource.new(episode: episode)
    mr.validate
    refute_nil mr.guid
    refute_nil mr.url
    assert_equal mr.status, "created"
  end

  it "answers if it is processed" do
    refute media_resource.status_complete?
    media_resource.status_complete!
    assert media_resource.status_complete?
  end

  it "sets url based on href" do
    mr = MediaResource.new(episode: episode)
    assert_nil mr.href
    mr.href = "http://test.prxu.org/somefile.mp3"
    assert_equal mr.href, "http://test.prxu.org/somefile.mp3"
    assert_equal mr.original_url, "http://test.prxu.org/somefile.mp3"
  end

  it "resets processing when href changes" do
    mr = build(:media_resource, episode: episode,
      status: MediaResource.statuses[:completed],
      original_url: "http://test.prxu.org/old.mp3")
    mr.status_complete!
    mr.task = Task.new

    mr.href = "http://test.prxu.org/somefile.mp3"
    assert_equal mr.href, "http://test.prxu.org/somefile.mp3"
    assert_equal mr.original_url, "http://test.prxu.org/somefile.mp3"
    refute mr.status_complete?
    assert_nil mr.task
  end

  it "removes query parameters" do
    mr = MediaResource.new(episode: episode, original_url: "http://test.prxu.org/somefile.mp3?foo=bar")
    assert_includes mr.original_url, "?foo=bar"
    refute_includes mr.url, "?foo=bar"
  end

  it "provides audio url based on guid" do
    assert_match(/https:\/\/f.prxu.org\/#{episode.podcast.path}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/, media_resource.media_url)
  end

  describe "#retryable?" do
    it "allows retrying stale processing" do
      mr = build_stubbed(:media_resource)
      refute mr.retryable?

      # updated 10 seconds ago
      mr.updated_at = Time.now - 10
      refute mr.tap { |i| i.status = "started" }.retryable?
      refute mr.tap { |i| i.status = "processing" }.retryable?
      refute mr.tap { |i| i.status = "complete" }.retryable?

      # updated 2 minutes ago
      mr.updated_at = Time.now - 120
      assert mr.tap { |i| i.status = "started" }.retryable?
      assert mr.tap { |i| i.status = "processing" }.retryable?
      refute mr.tap { |i| i.status = "complete" }.retryable?
    end
  end

  describe "#copy_media" do
    it "skips creating task if complete" do
      mr = build_stubbed(:media_resource, status: "complete")
      mr.task = nil
      mr.copy_media

      assert_nil mr.task
    end

    it "skips creating task if one exists" do
      mr = build_stubbed(:media_resource, status: "complete")
      task = Tasks::CopyImageTask.new
      mr.status = "created"
      mr.task = task
      mr.copy_media

      assert_equal task, mr.task
    end
  end

  describe "#retry!" do
    it "forces a new copy media job" do
      mock_copy = Minitest::Mock.new
      mock_copy.expect :call, nil, [true]

      media_resource.stub(:retryable?, true) do
        media_resource.stub(:copy_media, mock_copy) do
          media_resource.retry!
          assert media_resource.status_retrying?
        end
      end

      mock_copy.verify
    end
  end

  describe "#path" do
    it "returns a path without leading slash" do
      mr = MediaResource.new

      mr.stub(:media_url, "http://test.prxu.org/some/file.mp3") do
        assert_equal "some/file.mp3", mr.path
      end
    end
  end

  it "detects audio/video mediums" do
    mr = build_stubbed(:media_resource, status: "started", medium: nil)

    # detect audio from extension
    mr.original_url = "s3://some.where/file.mp3"
    assert mr.audio?
    refute mr.video?

    # detect video from extension
    mr.original_url = "s3://some.where/file.mov"
    refute mr.audio?
    assert mr.video?

    # override via medium
    mr.assign_attributes(status: "complete", medium: "blah")
    refute mr.audio?
    refute mr.video?
  end
end
