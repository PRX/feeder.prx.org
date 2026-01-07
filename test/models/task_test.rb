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

    it "decodes and creates stream recording tasks" do
      pod = create(:podcast)
      rec = create(:stream_recording, podcast: pod)
      job_id = "1234/#{rec.id}/2025-12-17T15:00Z/2025-12-17T16:00Z/some-guid.mp3"
      oxbow_received = build(:oxbow_job_received)
      oxbow_received[:JobReceived][:Job][:Id] = job_id
      oxbow_results = build(:oxbow_job_results)
      oxbow_results[:JobResult][:Job][:Id] = job_id

      # task and resource get created
      assert_difference("Tasks::RecordStreamTask.count", 1) do
        assert_difference("StreamResource.count", 1) do
          Task.callback(oxbow_received)
        end
      end

      res = rec.stream_resources.first
      assert_equal "processing", res.task.status
      assert_equal "recording", res.status
      assert_equal Time.parse("2025-12-17T15:00Z"), res.start_at
      assert_equal Time.parse("2025-12-17T16:00Z"), res.end_at

      # resource updated have task source
      StreamResource.stub_any_instance(:copy_media, true) do
        assert_difference("Tasks::RecordStreamTask.count", 0) do
          assert_difference("StreamResource.count", 0) do
            Task.callback(oxbow_results)
          end
        end
      end

      assert_equal "complete", res.reload.task.status
      assert_equal "processing", res.status
      assert_equal res.task.source_start_at, res.actual_start_at
      assert_equal res.task.source_end_at, res.actual_end_at
      assert_equal 4320, res.duration
      assert_equal 12345678, res.file_size
      assert_equal "s3://#{res.task.source_bucket}/#{res.task.source_key}", res.original_url
      assert_equal "#{pod.base_published_url}/streams/#{res.guid}/#{res.file_name}", res.url
    end

    it "logs errors for unrecognized tasks" do
      mock_log = Minitest::Mock.new
      mock_log.expect :call, nil do
        true
      end
      mock_notice = Minitest::Mock.new
      mock_notice.expect :call, nil do
        true
      end

      # NOTE: the stream_recording id in this won't exist
      oxbow_received = build(:oxbow_job_received)

      Rails.logger.stub(:error, mock_log) do
        NewRelic::Agent.stub(:notice_error, mock_notice) do
          assert_difference("Tasks::RecordStreamTask.count", 0) do
            assert_difference("StreamResource.count", 0) do
              Task.callback(oxbow_received)
            end
          end
        end
      end

      mock_log.verify
      mock_notice.verify
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

  describe "#bad_audio_vbr?" do
    it "checks for the vbr flag" do
      refute task.bad_audio_vbr?

      task.result = build(:porter_job_results)
      refute task.bad_audio_vbr?

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:VariableBitrate] = false
      refute task.bad_audio_vbr?

      task.result[:JobResult][:TaskResults][1][:Inspection][:Audio][:VariableBitrate] = true
      assert task.bad_audio_vbr?
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
          assert fake.verify
        end
      end
    end
  end
end
