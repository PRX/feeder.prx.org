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

  it "provides audio url based on guid" do
    assert_match(/https:\/\/f.prxu.org\/#{episode.podcast.path}\/ba047dce-9df5-4132-a04b-31d24c7c55a(\d+)\/ca047dce-9df5-4132-a04b-31d24c7c55a(\d+).mp3/, media_resource.media_url)
  end
end
