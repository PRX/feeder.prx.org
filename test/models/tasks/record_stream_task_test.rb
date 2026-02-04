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

  describe "#with_lock" do
    it "locks the stream resource" do
      task.stream_resource.stub(:with_lock, "res-lock") do
        assert task.stream_resource.persisted?
        assert_equal "res-lock", task.with_lock { true }
      end
    end

    it "locks the stream recording" do
      recording = build_stubbed(:stream_recording)
      task.owner = build(:stream_resource, stream_recording: recording)

      recording.stub(:with_lock, "rec-lock") do
        assert task.stream_resource.new_record?
        assert task.stream_recording.persisted?
        assert_equal "rec-lock", task.with_lock { true }
      end
    end

    it "falls back to locking itself" do
      recording = build(:stream_recording)
      task.owner = build(:stream_resource, stream_recording: recording)

      task.stub(:with_lock, "task-lock") do
        assert task.stream_resource.new_record?
        assert task.stream_recording.new_record?
        assert_equal "task-lock", task.with_lock { true }
      end
    end
  end

  describe "#update_owner?" do
    it "updates new recordings" do
      task.stream_resource.original_url = nil
      refute task.update_owner?

      task.status = "processing"
      assert task.update_owner?
    end

    it "updates the same recording url" do
      task.stream_resource.original_url = task.source_url
      refute task.update_owner?

      task.status = "processing"
      assert task.update_owner?
    end

    it "updates larger recordings" do
      assert_equal 0, task.missing_seconds
      assert_equal 0, task.stream_resource.missing_seconds
      refute_equal task.stream_resource.original_url, task.source_url
      refute task.update_owner?

      task.status = "processing"
      refute task.update_owner?

      task.stream_resource.actual_start_at = task.stream_resource.start_at + 1
      assert_equal 1, task.stream_resource.missing_seconds
      assert task.update_owner?

      task.stream_resource.actual_start_at = task.stream_resource.start_at - 1
      assert_equal 0, task.stream_resource.missing_seconds
      refute task.update_owner?
    end
  end

  describe "#update_owner" do
    let(:task) { create(:record_stream_task) }
    let(:resource) { task.stream_resource }

    it "updates status before save" do
      task.stub(:update_owner?, true) do
        assert_equal task.status, "complete"
        assert_equal resource.status, "complete"

        task.update(status: "started")
        assert_equal resource.status, "started"

        # we use "recording" instead of processing for this stage
        task.update(status: "processing")
        assert_equal resource.status, "recording"

        # but start "processing" once we've finished the recording
        mock = Minitest::Mock.new
        mock.expect(:call, nil)
        resource.stub(:copy_media, mock) do
          task.update(status: "complete")

          assert_equal "s3://#{task.source_bucket}/#{task.source_key}", resource.original_url
          assert_equal task.source_start_at, resource.actual_start_at
          assert_equal "processing", resource.status
          assert_equal task.source_size, resource.file_size
          assert_equal task.source_duration / 1000.0, resource.duration
          mock.verify
        end
      end
    end

    it "cancels previous copy/fix tasks" do
      copy = create(:copy_media_task, owner: resource)
      fix = create(:fix_media_task, owner: resource)

      mock = Minitest::Mock.new
      mock.expect(:call, nil)

      task.stub(:update_owner?, true) do
        resource.stub(:copy_media, mock) do
          task.update(status: "complete")

          assert_equal resource.status, "processing"
          assert_equal copy.reload.status, "cancelled"
          assert_equal fix.reload.status, "cancelled"
          mock.verify
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
