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
end
