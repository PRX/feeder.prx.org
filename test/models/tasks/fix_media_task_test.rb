require "test_helper"

describe Tasks::FixMediaTask do
  let(:task) { build_stubbed(:fix_media_task) }

  describe "#source_url" do
    it "is the media resource href" do
      task.media_resource.stub(:href, "whatev") do
        assert_equal "whatev", task.source_url
      end
    end
  end

  describe "#porter_tasks" do
    it "runs an ffmpeg task" do
      t = task.porter_tasks[0]

      assert_equal "Transcode", t[:Type]
      assert_equal "INHERIT", t[:Format]
      assert_equal "AWS/S3", t[:Destination][:Mode]
      assert_equal "test-prx-feed", t[:Destination][:BucketName]
      assert_equal task.media_resource.path, t[:Destination][:ObjectKey]
      assert_equal "-acodec copy", t[:FFmpeg][:OutputFileOptions]
    end
  end

  describe "#update_media_resource" do
    it "copies the task status to the media" do
      task.media_resource.stub(:save!, true) do
        task.status = "error"
        task.update_media_resource
        assert_equal "error", task.media_resource.status
      end
    end
  end
end
