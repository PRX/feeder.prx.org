require "test_helper"

describe StreamResource do
  let(:podcast) { build_stubbed(:podcast) }
  let(:resource) { build_stubbed(:stream_resource, podcast: podcast) }

  describe ".decode" do
    let(:rec) { create(:stream_recording) }
    let(:rec2) { create(:stream_recording) }

    it "finds or builds stream resources" do
      id = "1234/#{rec.id}/2025-12-17T15:00Z/2025-12-17T16:00Z/some-guid.mp3"
      res = StreamResource.decode(id)

      assert res.new_record?
      assert_equal rec.id, res.stream_recording_id
      assert_equal "2025-12-17T15:00Z".to_time, res.start_at
      assert_equal "2025-12-17T16:00Z".to_time, res.end_at

      # skip validations - we're just testing finding my stream+dates
      res.save(validate: false)
      assert res.persisted?

      # finding again returns the same resource
      assert_equal res, StreamResource.decode(id)
      assert_equal res, StreamResource.decode(id.sub("some-guid.mp3", "other-guid.mp3"))

      # but different recordings or dates are not new resources
      id2 = id.sub("/#{rec.id}/", "/#{rec2.id}/")
      assert StreamResource.decode(id2).new_record?
      assert StreamResource.decode(id.sub("15:00Z", "15:30Z")).new_record?
      assert StreamResource.decode(id.sub("16:00Z", "16:05Z")).new_record?

      # bad data is nil
      assert_nil StreamResource.decode(id.sub("1234/", "abcd/"))
      assert_nil StreamResource.decode(id.sub("/#{rec.id}/", "/abcd/"))
      assert_nil StreamResource.decode(id.sub("17T15:00Z", ""))
      assert_nil StreamResource.decode(id.sub("17T16:00Z", ""))
      assert_nil StreamResource.decode("1234/5678/something")
      assert_nil StreamResource.decode("whatev")
    end
  end

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

    it "skips creating a copy_task if one exists" do
      res = build_stubbed(:stream_resource, status: "processing")
      task = Tasks::CopyMediaTask.new
      res.status = "processing"
      res.copy_task = task
      res.copy_media

      assert_equal task, res.copy_task
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
end
