require "test_helper"

describe Tasks::FixMediaTask do
  let(:task) { build_stubbed(:fix_media_task) }

  describe ".start!" do
    let(:content) { create(:content, status: "complete") }
    let(:copy_task) { build_stubbed(:copy_media_task) }

    it "starts a fix media task" do
      copy_task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:DurationDiscrepancy] = 1000
      copy_task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:VariableBitrate] = true

      Tasks::FixMediaTask.stub_any_instance(:porter_start!, true) do
        assert_difference("Tasks::FixMediaTask.count", 1) do
          Tasks::FixMediaTask.start!(content, copy_task)
        end
      end

      task = content.task
      assert_equal Tasks::FixMediaTask, task.media_resource.task.class
      assert_equal "mp3", task.media_resource.task.options[:Tasks][0][:Format]
      assert_equal "-b:a 192k", task.media_resource.task.options[:Tasks][0][:FFmpeg][:OutputFileOptions]
      assert_equal "processing", content.status
    end
  end

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

  describe "#update_owner" do
    it "copies the task status to the media" do
      task.media_resource.stub(:save!, true) do
        task.status = "error"
        task.update_owner
        assert_equal "error", task.media_resource.status
      end
    end
  end
end
