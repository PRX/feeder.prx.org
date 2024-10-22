require "test_helper"

describe Tasks::CopyTranscriptTask do
  let(:task) { build_stubbed(:copy_transcript_task) }

  describe "#source_url" do
    it "is the transcript href" do
      task.transcript.stub(:href, "whatev") do
        assert_equal "whatev", task.source_url
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
      assert_equal task.transcript.path, t[:ObjectKey]
      assert_equal "REPLACE", t[:ContentType]
      assert_equal "max-age=86400", t[:Parameters][:CacheControl]
      assert_equal "attachment; filename=\"sampletranscript.html\"", t[:Parameters][:ContentDisposition]
    end

    it "escapes http source urls" do
      task.transcript.original_url = "http://some/where/my%20file.html"

      task.transcript.stub(:path, "some/where/this%20goes") do
        t = task.porter_tasks[1]

        assert_equal "Copy", t[:Type]
        assert_equal "some/where/this goes", t[:ObjectKey]
        assert_equal "attachment; filename=\"my file.html\"", t[:Parameters][:ContentDisposition]
      end
    end
  end

  describe "#update_transcript" do
    let(:task) { create(:copy_transcript_task) }

    it "updates status before save" do
      assert_equal task.status, "complete"
      assert_equal task.transcript.status, "complete"
      task.update(status: "processing")
      assert_equal task.status, "processing"
      assert_equal task.transcript.status, "processing"
    end

    it "updates transcript metadata on complete" do
      task.transcript.reset_transcript_attributes

      task.update(status: "created")
      assert_nil task.transcript.file_size
      assert_nil task.transcript.mime_type

      task.update(status: "complete")
      assert_equal 60572, task.transcript.file_size
      assert_equal "text/html", task.transcript.mime_type
    end

    it "handles validation errors" do
      task.update(status: "created")

      task.result[:JobResult][:TaskResults][1][:Inspection][:MIME] = "bad"
      task.update(status: "complete")

      assert_equal "invalid", task.transcript.status
      assert_equal "bad", task.transcript.mime_type
    end
  end
end
