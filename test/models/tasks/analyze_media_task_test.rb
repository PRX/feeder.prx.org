require "test_helper"

describe Tasks::AnalyzeMediaTask do
  let(:task) { build_stubbed(:analyze_media_task) }

  describe "#source_url" do
    it "is the media resource href" do
      task.media_resource.stub(:original_url, "whatev") do
        assert_equal "whatev", task.source_url
      end
    end
  end

  describe "#porter_tasks" do
    it "runs an inspect task" do
      assert_equal "Inspect", task.porter_tasks[0][:Type]
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
      publish = Minitest::Mock.new

      task.media_resource.episode.stub(:publish!, publish) do
        task.update(status: "created")
        assert publish.verify

        publish.expect(:call, nil)
        task.update(status: "complete")
        assert publish.verify
      end
    end

    it "updates audio metadata on complete" do
      task.media_resource.reset_media_attributes

      task.update(status: "created")
      assert_nil task.media_resource.mime_type

      task.update(status: "complete")
      assert_equal 192, task.media_resource.bit_rate
      assert_equal 2, task.media_resource.channels
      assert_equal 1371.437, task.media_resource.duration
      assert_equal 32980032, task.media_resource.file_size
      assert_equal "audio", task.media_resource.medium
      assert_equal "audio/mpeg", task.media_resource.mime_type
      assert_equal 48000, task.media_resource.sample_rate

      # this audio has a video stream (the ID3 image) - but we should
      # not be parsing the metadata for it
      assert_nil task.media_resource.frame_rate
      assert_nil task.media_resource.height
      assert_nil task.media_resource.width
    end
  end
end
