require "test_helper"

describe Tasks::TranscodeHlsTask do
  let(:task) { build_stubbed(:transcode_hls_task) }

  describe "#source_url" do
    it "is the original url" do
      task.media_resource.original_url = "http://some.where"
      assert_equal "http://some.where", task.source_url
    end
  end

  describe "#porter_tasks" do
    it "runs an hls task" do
      assert_equal "HLS", task.porter_tasks[0][:Type]
      assert_equal "Standard Podcast 2026 v1", task.porter_tasks[0][:Preset]
    end

    it "uses the start timestamps of segmentation breaks" do
      task.media_resource.segmentation = [[nil, nil]]
      assert_equal [], task.porter_tasks[0][:AdBreaks]

      task.media_resource.segmentation = [[nil, 10.0], [10.0, nil]]
      assert_equal [10.0], task.porter_tasks[0][:AdBreaks]

      task.media_resource.segmentation = [[nil, 10.0], [20.0, nil]]
      assert_equal [10.0], task.porter_tasks[0][:AdBreaks]

      task.media_resource.segmentation = [[2.0, 10.0], [10.0, 50.0], [60.0, nil]]
      assert_equal [10.0, 50.0], task.porter_tasks[0][:AdBreaks]
    end
  end
end
