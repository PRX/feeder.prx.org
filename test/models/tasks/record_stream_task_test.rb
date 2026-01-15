require "test_helper"

describe Tasks::RecordStreamTask do
  let(:task) { build_stubbed(:record_stream_task) }
  let(:t1) { "2026-01-06T18:00Z" }
  let(:t2) { "2026-01-06T19:00Z" }

  describe ".from_job_id" do
    let(:stream) { create(:stream_recording) }

    it "returns nil for badly formatted job_ids" do
      assert_nil Tasks::RecordStreamTask.from_job_id("")
      assert_nil Tasks::RecordStreamTask.from_job_id("whatev")
      assert_nil Tasks::RecordStreamTask.from_job_id("123/456/3/4/5.mp3")
      assert_nil Tasks::RecordStreamTask.from_job_id("123/456/#{t1}/4/5.mp3")
      assert_nil Tasks::RecordStreamTask.from_job_id("123/456/3/#{t2}/5.mp3")
      assert_nil Tasks::RecordStreamTask.from_job_id("123/456/#{t1}/2026-99-99T99:00Z/5.mp3")
    end

    it "returns nil for non-existent streams" do
      assert_nil Tasks::RecordStreamTask.from_job_id("123/456/#{t1}/#{t2}/5")
    end

    it "builds new resources" do
      job_id = "123/#{stream.id}/#{t1}/#{t2}/5.mp3"

      task = Tasks::RecordStreamTask.from_job_id(job_id)
      assert task.new_record?
      assert_equal job_id, task.job_id
      assert_equal "started", task.status

      res = task.owner
      assert res.new_record?
      assert_equal stream.id, res.stream_recording_id
      assert_equal Time.parse(t1), res.start_at
      assert_equal Time.parse(t2), res.end_at
      assert_equal "created", res.status
    end

    it "finds existing resources" do
      job_id = "123/#{stream.id}/#{t1}/#{t2}/5.mp3"
      res = create(:stream_resource, stream_recording: stream, start_at: t1, end_at: t2)

      task = Tasks::RecordStreamTask.from_job_id(job_id)
      assert task.new_record?
      assert_equal job_id, task.job_id
      assert_equal "started", task.status
      assert_equal res, task.owner
    end
  end

  describe "#update_stream_resource" do
    let(:task) { create(:record_stream_task) }
    let(:resource) { task.stream_resource }

    it "updates status before save" do
      assert_equal task.status, "complete"
      assert_equal resource.status, "complete"

      task.update(status: "started")
      assert_equal resource.status, "started"

      # we use "recording" instead of processing for this stage
      task.update(status: "processing")
      assert_equal resource.status, "recording"

      # but start "processing" once we've finished the recording
      task.update(status: "complete")
      assert_equal resource.status, "complete"
    end

    it "copies media the first time" do
      resource.update(actual_start_at: nil, actual_end_at: nil, original_url: nil)
      assert_equal 3600, resource.missing_seconds

      mock_copy = Minitest::Mock.new
      mock_copy.expect(:call, nil)

      resource.stub(:copy_media, mock_copy) do
        task.stub(:missing_seconds, 10) do
          task.update_stream_resource

          assert_equal "s3://#{task.source_bucket}/#{task.source_key}", resource.original_url
          assert_equal task.source_start_at, resource.actual_start_at
          assert_equal task.source_end_at, resource.actual_end_at
          assert_equal "processing", resource.status
          assert_equal task.source_size, resource.file_size
          assert_equal task.source_duration / 1000.0, resource.duration

          mock_copy.verify
        end
      end
    end

    it "copies media with the fewest missing_seconds" do
      old_orig = "s3://some/previous/file.mp3"

      # pretend resource is 10 seconds short
      resource.update(actual_start_at: resource.start_at + 10.seconds, original_url: old_orig)
      assert_equal 10, resource.missing_seconds

      task.stub(:missing_seconds, 12) do
        task.update_stream_resource
        assert_equal old_orig, resource.original_url
      end

      task.stub(:missing_seconds, 10) do
        task.update_stream_resource
        assert_equal old_orig, resource.original_url
      end

      mock_copy = Minitest::Mock.new
      mock_copy.expect(:call, nil)

      # has fewer missing seconds - copy this one
      resource.stub(:copy_media, mock_copy) do
        task.stub(:missing_seconds, 8) do
          task.update_stream_resource
          refute_equal old_orig, resource.original_url

          assert_equal "s3://#{task.source_bucket}/#{task.source_key}", resource.original_url
          assert_equal task.source_start_at, resource.actual_start_at
          assert_equal "processing", resource.status
          assert_equal task.source_size, resource.file_size
          assert_equal task.source_duration / 1000.0, resource.duration

          mock_copy.verify
        end
      end
    end
  end

  describe "#job_id_parts" do
    it "parses the various parts of the job id" do
      assert_equal 1234, task.podcast_id
      assert_equal 5678, task.stream_recording_id
      assert_equal Time.parse("2025-12-17 15:00Z"), task.start_at
      assert_equal Time.parse("2025-12-17 16:00Z"), task.end_at
      assert_equal "27a8112d-b582-4d23-8d73-257e543d64a4.mp3", task.file_name
      assert task.job_id_valid?
    end

    it "returns nil for badly formatted job_ids" do
      task.job_id = "a/b/c/2025-99-99/"

      assert_nil task.podcast_id
      assert_nil task.stream_recording_id
      assert_nil task.start_at
      assert_nil task.end_at
      assert_nil task.file_name
      refute task.job_id_valid?
    end
  end

  describe "#source" do
    it "parses ffmpeg callback data" do
      assert_equal "prx-feed-testing", task.source_bucket
      assert_equal task.job_id, task.source_key
      assert_equal 12345678, task.source_size
      assert_equal 72.minutes.in_seconds * 1000, task.source_duration
      assert_equal Time.parse("2025-12-17 14:55:21Z"), task.source_start_at
      assert_equal Time.parse("2025-12-17 16:07:21Z"), task.source_end_at
    end

    it "returns nil if not present" do
      task.result = nil

      assert_nil task.source_bucket
      assert_nil task.source_key
      assert_nil task.source_size
      assert_nil task.source_duration
      assert_nil task.source_start_at
      assert_nil task.source_end_at
    end
  end

  describe "#missing_seconds" do
    it "returns the seconds we're missing for the time range" do
      assert_equal 0, task.missing_seconds

      task.result[:JobResult][:TaskResults][0][:FFmpeg][:Outputs][0][:StartEpoch] = task.start_at.to_i
      assert_equal 0, task.missing_seconds

      task.result[:JobResult][:TaskResults][0][:FFmpeg][:Outputs][0][:StartEpoch] = task.start_at.to_i + 1
      assert_equal 1, task.missing_seconds

      task.result[:JobResult][:TaskResults][0][:FFmpeg][:Outputs][0][:StartEpoch] = task.start_at.to_i - 11
      task.result[:JobResult][:TaskResults][0][:FFmpeg][:Outputs][0][:Duration] = 59.minutes.in_seconds * 1000
      assert_equal 71, task.missing_seconds

      task.result[:JobResult][:TaskResults][0][:FFmpeg][:Outputs][0][:StartEpoch] = task.start_at.to_i + 60
      task.result[:JobResult][:TaskResults][0][:FFmpeg][:Outputs][0][:Duration] = 51.minutes.in_seconds * 1000
      assert_equal 9.minutes.in_seconds, task.missing_seconds
    end
  end
end
