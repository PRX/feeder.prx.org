require "test_helper"

describe Tasks::CopyMediaTask do
  let(:task) { build_stubbed(:copy_media_task) }

  describe "#source_url" do
    it "is the media resource href" do
      task.media_resource.stub(:href, "whatev") do
        assert_equal "whatev", task.source_url
      end
    end

    it "is always the original url for sliced segments" do
      task.media_resource.segmentation = [1.23, 4.56]
      task.media_resource.original_url = "http://some.where"

      assert task.media_resource.slice?

      task.media_resource.stub(:href, "http://else.where") do
        assert_equal "http://some.where", task.source_url
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

    it "optionally runs an inspect task" do
      assert_equal 2, task.porter_tasks.count

      task.media_resource.stub(:generate_waveform?, true) do
        assert_equal 3, task.porter_tasks.count

        t = task.porter_tasks[2]
        assert_equal "Waveform", t[:Type]
        assert_equal "BBC/audiowaveform/v1.x", t[:Generator]
        assert_equal "JSON", t[:DataFormat]
        assert_equal "AWS/S3", t[:Destination][:Mode]
        assert_equal "test-prx-feed", t[:Destination][:BucketName]
        assert_equal task.media_resource.waveform_path, t[:Destination][:ObjectKey]
      end
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
      publish = Minitest::Mock.new

      task.media_resource.episode.stub(:publish!, publish) do
        task.update(status: "created")
        assert publish.verify

        publish.expect(:call, nil)
        task.update(status: "complete")
        assert publish.verify
      end
    end

    it "calls slice on uncut resources on complete" do
      slice = Minitest::Mock.new
      slice.expect(:call, nil)

      uncut = build(:uncut)

      task.stub(:media_resource, uncut) do
        uncut.stub(:slice_contents, slice) do
          task.update_media_resource
          assert slice.verify
        end
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

    it "updates video metadata on complete" do
      task.result[:JobResult][:TaskResults][1] = build(:porter_inspect_video_result)
      task.media_resource.reset_media_attributes

      task.update(status: "created")
      assert_nil task.media_resource.mime_type

      task.update(status: "complete")
      assert_equal 157.991, task.media_resource.duration
      assert_equal 16996018, task.media_resource.file_size
      assert_equal 24, task.media_resource.frame_rate
      assert_equal 360, task.media_resource.height
      assert_equal "video", task.media_resource.medium
      assert_equal "video/mp4", task.media_resource.mime_type
      assert_equal 640, task.media_resource.width

      # for videos we _do_ get some audio stream metadata
      assert_equal 109, task.media_resource.bit_rate
      assert_equal 2, task.media_resource.channels
      assert_equal 44100, task.media_resource.sample_rate
    end

    it "does not throw errors when owner is missing on callback" do
      task.owner = nil
      task.update(status: "complete")
      assert_equal "complete", task.status
    end

    it "handles validation errors" do
      task.update(status: "created")

      task.result[:JobResult][:TaskResults][1][:Inspection][:MIME] = "foo/bar"
      task.update(status: "complete")

      assert_equal "invalid", task.media_resource.status
      assert_equal "foo", task.media_resource.medium
    end

    it "runs a FixMediaTask if the duration was mismatched" do
      task.update(status: "created")

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:DurationDiscrepancy] = 1000

      Task.stub_any_instance(:porter_start!, true) do
        assert_difference("Tasks::FixMediaTask.count", 1) do
          task.update(status: "complete")

          # status is still processing
          assert_equal "processing", task.media_resource.status

          # latest task is now to fix
          assert_equal Tasks::FixMediaTask, task.media_resource.task.class
          assert_equal "mp3", task.media_resource.task.options[:Tasks][0][:Format]
          assert_equal "-acodec copy", task.media_resource.task.options[:Tasks][0][:FFmpeg][:OutputFileOptions]
        end
      end
    end

    it "runs a FixMediaTask if the audio was vbr" do
      task.update(status: "created")

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:VariableBitrate] = true

      Task.stub_any_instance(:porter_start!, true) do
        assert_difference("Tasks::FixMediaTask.count", 1) do
          task.update(status: "complete")

          # status is still processing
          assert_equal "processing", task.media_resource.status

          # latest task is now to fix
          assert_equal Tasks::FixMediaTask, task.media_resource.task.class
          assert_equal "mp3", task.media_resource.task.options[:Tasks][0][:Format]
          assert_equal "-acodec copy -b:a 192k", task.media_resource.task.options[:Tasks][0][:FFmpeg][:OutputFileOptions]
        end
      end
    end
  end

  describe "#next_highest_bitrate" do
    it "returns the next highest common bitrate" do
      assert_equal 192, task.next_highest_bitrate

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:Bitrate] = 195678
      assert_equal 224, task.next_highest_bitrate

      # 320 is the  max
      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:Bitrate] = 999999
      assert_equal 320, task.next_highest_bitrate

      # 128 is the default
      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:Bitrate] = nil
      assert_equal 128, task.next_highest_bitrate
    end
  end
end
