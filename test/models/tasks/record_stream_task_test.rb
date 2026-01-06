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
end
