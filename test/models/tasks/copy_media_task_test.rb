require "test_helper"

describe Tasks::CopyMediaTask do
  let(:task) { build_stubbed(:copy_media_task) }

  describe "#source_url" do
    it "is the media resource href" do
      task.media_resource.stub(:href, "whatev") do
        assert_equal "whatev", task.source_url
      end
    end
  end

  describe "#porter_tasks" do
    it "runs an inspect task" do
      assert_equal "Inspect", task.porter_tasks[0][:Type]
    end

    it "runs a copy task" do
      t = task.porter_tasks[1]

      assert_equal "Copy", t[:Type]
      assert_equal "AWS/S3", t[:Mode]
      assert_equal "test-prx-feed", t[:BucketName]
      assert_equal task.media_resource.path, t[:ObjectKey]
      assert_equal "REPLACE", t[:ContentType]
      assert_equal "max-age=86400", t[:Parameters][:CacheControl]
      assert_equal "attachment; filename=\"audio.mp3\"", t[:Parameters][:ContentDisposition]
    end

    it "escapes http source urls" do
      task.media_resource.original_url = "http://some/where/my%20file.mp3"

      task.media_resource.stub(:path, "some/where/this%20goes") do
        t = task.porter_tasks[1]

        assert_equal "Copy", t[:Type]
        assert_equal "some/where/this goes", t[:ObjectKey]
        assert_equal "attachment; filename=\"my file.mp3\"", t[:Parameters][:ContentDisposition]
      end
    end
  end

  describe "#update_media_resource" do
    let(:task) { create(:copy_media_task) }

    it "updates status before save" do
      assert_equal task.status, "complete"
      assert_equal task.media_resource.status, "complete"
      task.update(status: "processing")
      assert_equal task.status, "processing"
      assert_equal task.media_resource.status, "processing"
    end

    it "replaces resources and publishes on complete" do
      publish = MiniTest::Mock.new

      task.podcast.stub(:publish!, publish) do
        task.update(status: "created")
        publish.verify

        publish.expect(:call, nil)
        task.update(status: "complete")
        publish.verify
      end
    end

    it "updates audio metadata on complete" do
      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:Bitrate] = "999000"

      task.update(status: "created")
      refute_equal task.media_resource.bit_rate, 999

      task.update(status: "complete")
      assert_equal task.media_resource.bit_rate, 999
    end

    it "does not throw errors when owner is missing on callback" do
      task.owner = nil
      task.update(status: "complete")
    end

    it "handles validation errors" do
      task.update(status: "created")

      task.result[:JobResult][:TaskResults][1][:Inspection][:MIME] = "foo/bar"
      task.update(status: "complete")

      assert_equal "invalid", task.media_resource.status
      assert_equal "foo", task.media_resource.medium
    end
  end
end
