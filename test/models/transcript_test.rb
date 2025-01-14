require "test_helper"

describe Transcript do
  let(:episode) { build_stubbed(:episode) }
  let(:url) { "http://sample/url/transcript.html" }
  let(:transcript) { build_stubbed(:transcript, episode: episode) }

  describe "#valid?" do
    before do
      assert transcript.valid?
    end

    it "requires an original_url" do
      transcript.original_url = nil
      refute transcript.valid?
    end

    it "must have a format" do
      transcript.format = nil
      refute transcript.valid?
    end
  end

  describe "#copy_media" do
    it "creates a task" do
      task = Tasks::CopyTranscriptTask.new
      create_task = ->(&block) do
        block.call(task)
        task
      end

      Tasks::CopyTranscriptTask.stub(:create!, create_task) do
        task.stub(:start!, true) do
          transcript.status = "created"
          transcript.task = nil
          transcript.copy_media
          assert_equal transcript, task.owner
        end
      end
    end

    it "skips creating task if complete" do
      transcript.task = nil
      assert transcript.status_complete?
      transcript.copy_media

      assert_nil transcript.task
    end

    it "skips creating task if one exists" do
      task = Tasks::CopyTranscriptTask.new
      transcript.status = "created"
      transcript.task = task
      transcript.copy_media

      assert_equal task, transcript.task
    end
  end

  describe "rss_mime_type" do
    it "returns the mime type for the transcript format" do
      assert_equal "text/html", transcript.rss_mime_type

      transcript.format = "json"
      assert_equal "application/json", transcript.rss_mime_type

      transcript.format = nil
      assert_nil transcript.rss_mime_type

      # pretend bad data got into the db somehow
      transcript.stub(:format, "whatev") do
        assert_nil transcript.rss_mime_type
      end
    end
  end
end
