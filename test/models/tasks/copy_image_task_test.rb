require "test_helper"

describe Tasks::CopyImageTask do
  let(:task) { build_stubbed(:copy_image_task) }

  describe "#source_url" do
    it "is the image href" do
      task.image.stub(:href, "whatev") do
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
      assert_equal task.image.path, t[:ObjectKey]
      assert_equal "REPLACE", t[:ContentType]
      assert_equal "max-age=86400", t[:Parameters][:CacheControl]
      assert_equal "attachment; filename=\"image.png\"", t[:Parameters][:ContentDisposition]
    end

    it "escapes http source urls" do
      task.image.original_url = "http://some/where/my%20file.jpg"

      task.image.stub(:path, "some/where/this%20goes") do
        t = task.porter_tasks[1]

        assert_equal "Copy", t[:Type]
        assert_equal "some/where/this goes", t[:ObjectKey]
        assert_equal "attachment; filename=\"my file.jpg\"", t[:Parameters][:ContentDisposition]
      end
    end
  end

  describe "#update_image" do
    let(:task) { create(:copy_image_task) }

    it "updates status before save" do
      assert_equal task.status, "complete"
      assert_equal task.image.status, "complete"
      task.update(status: "processing")
      assert_equal task.status, "processing"
      assert_equal task.image.status, "processing"
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

    it "updates image metadata on complete" do
      task.image.reset_image_attributes

      task.update(status: "created")
      assert_nil task.image.format

      task.update(status: "complete")
      assert_equal "jpeg", task.image.format
      assert_equal 1400, task.image.height
      assert_equal 1400, task.image.width
      assert_equal 60572, task.image.size
    end

    it "handles validation errors" do
      task.update(status: "created")

      task.result[:JobResult][:TaskResults][1][:Inspection][:Image][:Format] = "bad"
      task.update(status: "complete")

      assert_equal "invalid", task.image.status
      assert_equal "bad", task.image.format
    end
  end
end
