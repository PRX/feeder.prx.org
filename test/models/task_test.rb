require "test_helper"

describe Task do
  let(:porter_task) { build(:porter_job_results) }
  let(:task) { Task.new }

  describe ".callback" do
    it "finds tasks by job_id" do
      task.update!(job_id: porter_task[:JobResult][:Job][:Id])
      assert task.started?

      Task.callback(porter_task)
      assert task.reload.complete?
      assert_equal task.logged_at, Time.parse("2012-12-21T12:34:56Z")
    end

    it "ignores porter task results" do
      task.update!(job_id: porter_task[:JobResult][:Job][:Id])
      assert task.started?
      assert_nil task.logged_at

      porter_task["TaskResult"] = porter_task.delete("JobResult")
      Task.callback(porter_task)
      assert task.reload.started?
      assert_nil task.logged_at
    end

    it "ignores stale event timestamps" do
      task.update!(job_id: porter_task[:JobResult][:Job][:Id], logged_at: Time.now)
      assert task.started?

      Task.callback(porter_task)
      refute task.reload.complete?
    end
  end

  describe "#job_id" do
    it "generates uuids" do
      id1 = task.job_id
      assert_equal 36, id1.length

      task.job_id = nil

      id2 = task.job_id
      assert_equal 36, id2.length
      refute_equal id1, id2
    end
  end

  describe "#source_url" do
    it "leaves implementation to child classes" do
      assert_nil task.source_url
    end
  end

  describe "#bad_audio_duration?" do
    it "checks for duration discrepancy over 500ms" do
      refute task.bad_audio_duration?

      task.result = build(:porter_job_results)
      refute task.bad_audio_duration?

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:DurationDiscrepancy] = 500
      refute task.bad_audio_duration?

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:DurationDiscrepancy] = 501
      assert task.bad_audio_duration?
    end
  end

  describe "#bad_audio_bytes?" do
    it "checks for unidentified audio bytes" do
      refute task.bad_audio_bytes?

      task.result = build(:porter_job_results)
      refute task.bad_audio_bytes?

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:UnidentifiedBytes] = 0
      refute task.bad_audio_bytes?

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:UnidentifiedBytes] = 1
      assert task.bad_audio_bytes?
    end
  end

  describe "#start!" do
    it "starts a porter job" do
      task.stub(:source_url, "http://some/file.mp3") do
        job = {
          "Id" => task.job_id,
          "Source" => task.porter_source.with_indifferent_access,
          "Tasks" => [],
          "Callbacks" => task.porter_callbacks.map(&:with_indifferent_access)
        }

        fake = Minitest::Mock.new
        fake.expect :call, nil, [job]

        task.stub(:porter_start!, fake) do
          task.start!
          fake.verify
        end
      end
    end
  end
end
