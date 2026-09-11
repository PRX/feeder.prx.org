require "test_helper"

describe Tasks::SliceMediaTask do
  let(:task) { build_stubbed(:slice_media_task) }

  describe "#source_url" do
    it "is the original url" do
      task.media_resource.segmentation = [1.23, 4.56]
      task.media_resource.original_url = "http://some.where"

      task.media_resource.stub(:href, "http://else.where") do
        assert_equal "http://some.where", task.source_url
      end
    end
  end

  describe "#porter_tasks" do
    it "runs an inspect task" do
      assert_equal "Inspect", task.porter_tasks[0][:Type]
    end

    it "runs a transcode task" do
      t = task.porter_tasks[1]

      assert_equal "Transcode", task.porter_tasks[1][:Type]
      assert_equal "INHERIT", task.porter_tasks[1][:Format]
      assert_equal "AWS/S3", t[:Destination][:Mode]
      assert_equal "test-prx-feed", t[:Destination][:BucketName]
      assert_equal task.media_resource.path, t[:Destination][:ObjectKey]
      assert_equal "REPLACE", t[:Destination][:ContentType]
      assert_equal "max-age=86400", t[:Destination][:Parameters][:CacheControl]
      assert_equal "attachment; filename=\"audio.mp3\"", t[:Destination][:Parameters][:ContentDisposition]
    end

    it "sets start and end args" do
      assert_equal "-map_metadata 0 -c copy", task.porter_tasks.dig(1, :FFmpeg, :OutputFileOptions)

      task.media_resource.slice_start = 1.23
      assert_equal "-map_metadata 0 -c copy -ss 1.23", task.porter_tasks.dig(1, :FFmpeg, :OutputFileOptions)

      task.media_resource.slice_end = 4.56
      assert_equal "-map_metadata 0 -c copy -ss 1.23 -to 4.56", task.porter_tasks.dig(1, :FFmpeg, :OutputFileOptions)

      task.media_resource.slice_start = nil
      assert_equal "-map_metadata 0 -c copy -to 4.56", task.porter_tasks.dig(1, :FFmpeg, :OutputFileOptions)
    end
  end

  describe "#update_owner" do
    let(:task) { create(:slice_media_task) }

    it "overrides sliced audio with the new size/duration" do
      task.media_resource.update!(segmentation: [5, 10])

      task.result[:JobResult][:TaskResults] << build(:porter_slice_audio_result)
      task.media_resource.reset_media_attributes

      task.update(status: "created")
      assert_nil task.media_resource.mime_type

      task.update(status: "complete")
      assert_equal 9.999, task.media_resource.duration
      assert_equal 9999, task.media_resource.file_size
    end
  end
end
