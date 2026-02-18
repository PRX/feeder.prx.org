require "test_helper"

describe StreamResource do
  let(:podcast) { build_stubbed(:podcast) }
  let(:resource) { build_stubbed(:stream_resource, podcast: podcast) }

  describe "#set_defaults" do
    it "sets unchanged defaults" do
      res = StreamResource.new(podcast: podcast)
      assert_equal "created", res.status
      assert res.guid.present?
      assert res.url.present?
      refute res.changed?
    end
  end

  describe "#copy_media" do
    it "skips creating a copy_task if complete" do
      res = build_stubbed(:stream_resource, status: "complete")
      res.copy_task = nil
      res.copy_media

      assert_nil res.copy_task
    end

    it "skips copying if the recording is still in progress" do
      res = build_stubbed(:stream_resource, status: "recording")
      res.copy_task = nil
      res.copy_media
      assert_nil res.copy_task

      res.status = "created"
      res.copy_media
      assert_nil res.copy_task
    end

    it "skips creating a copy_task if one exists" do
      res = build_stubbed(:stream_resource, status: "processing")
      task = Tasks::CopyMediaTask.new
      res.status = "processing"
      res.copy_task = task
      res.copy_media

      assert_equal task, res.copy_task
    end

    it "creates another copy task if the previous one is cancelled" do
      res = create(:stream_resource, status: "processing")

      Tasks::CopyMediaTask.stub_any_instance(:start!, true) do
        res.copy_media
        t1 = res.reload.copy_task
        assert_equal "started", t1.status

        # cancel this task, and copy_media again
        t1.update!(status: "cancelled")
        assert_nil res.reload.copy_task
        res.copy_media
        t2 = res.reload.copy_task
        assert_equal "started", t2.status
        refute_equal t1, t2
      end
    end
  end

  describe "#file_name" do
    it "parses the original url" do
      assert_equal "audio.mp3", resource.file_name

      resource.original_url = "http://some.where/the/file.name.here#and?other&stuff=1"
      assert_equal "file.name.here", resource.file_name

      resource.original_url = ""
      assert_nil resource.file_name
    end
  end

  describe "#path" do
    it "includes the podcast prefix" do
      assert_equal "#{podcast.id}/streams/#{resource.guid}/audio.mp3", resource.path
    end
  end

  describe "#published_url" do
    it "includes the podcast http url" do
      assert_equal "https://f.prxu.org/#{resource.path}", resource.published_url
    end

    it "sets the url field" do
      refute_nil resource.url
      assert_equal resource.published_url, resource.url

      resource.guid = "some-other-guid"
      resource.original_url = "http://some/other.filename"
      assert resource.valid?
      refute_equal resource.published_url, resource.url
    end
  end

  describe "#href" do
    it "returns the original url until complete/invalid" do
      assert resource.valid?

      resource.status = "recording"
      assert_equal resource.original_url, resource.href

      resource.status = "processing"
      assert_equal resource.original_url, resource.href

      resource.status = "complete"
      assert_equal resource.url, resource.href

      resource.status = "invalid"
      assert_equal resource.url, resource.href
    end
  end

  describe "#medium" do
    it "hardcodes the medium" do
      assert_equal "audio", resource.medium

      resource.medium = "whatev"
      assert_equal "audio", resource.medium
    end
  end

  describe "#waveform_url" do
    it "generates waveforms next to the audio file" do
      assert resource.generate_waveform?
      refute resource.slice?

      assert_equal "#{resource.url}.json", resource.waveform_url
      assert_equal "#{resource.path}.json", resource.waveform_path
      assert_equal "#{resource.file_name}.json", resource.waveform_file_name
    end
  end

  describe "#missing_seconds" do
    it "returns the seconds we're missing for the time range" do
      assert_equal 0, resource.missing_seconds

      resource.actual_start_at = resource.start_at
      assert_equal 0, resource.missing_seconds

      resource.actual_start_at = resource.start_at + 1.second
      assert_equal 1, resource.missing_seconds

      resource.actual_start_at = resource.start_at - 11.seconds
      resource.actual_end_at = resource.end_at - 71.seconds
      assert_equal 71, resource.missing_seconds

      resource.actual_start_at = resource.start_at + 1.minute
      resource.actual_end_at = resource.end_at - 8.minutes
      assert_equal 9.minutes, resource.missing_seconds
    end
  end

  describe "#segmentation" do
    let(:res) { Resource.new }

    it "calculates the actual start/end offsets" do
      res = StreamResource.new(start_at: "2026-02-06T02:00Z", end_at: "2026-02-06T03:00Z")
      assert_equal [], res.segmentation
      assert_equal 0, res.offset_start
      assert_equal 0, res.offset_duration

      res.actual_start_at = "2026-02-06T01:55Z"
      res.actual_end_at = "2026-02-06T03:05Z"
      assert_equal [[300, 3900]], res.segmentation
      assert_equal 300, res.offset_start
      assert_equal 3600, res.offset_duration

      res.actual_start_at = "2026-02-06T02:01Z"
      assert_equal [[0, 3540]], res.segmentation
      assert_equal 0, res.offset_start
      assert_equal 3540, res.offset_duration

      res.actual_end_at = "2026-02-06T02:30Z"
      assert_equal [[0, 1740]], res.segmentation
      assert_equal 0, res.offset_start
      assert_equal 1740, res.offset_duration
    end
  end
end
