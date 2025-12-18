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

  describe "#file_name" do
    it "parses the original url" do
      assert_equal "audio.mp3", resource.file_name

      resource.original_url = "http://some.where/the/file.name.here#and?other&stuff=1"
      assert_equal "file.name.here", resource.file_name

      resource.original_url = ""
      assert_nil resource.file_name
    end
  end

  describe "#published_path" do
    it "includes the podcast prefix" do
      assert_equal "#{podcast.id}/streams/#{resource.guid}/audio.mp3", resource.published_path
    end
  end

  describe "#published_url" do
    it "includes the podcast http url" do
      assert_equal "https://f.prxu.org/#{resource.published_path}", resource.published_url
    end

    it "sets the url field" do
      # NOTE: podcast is nil after_initialize
      assert_nil resource.url

      # but will be there before validation
      assert resource.valid?
      refute_nil resource.url
      assert_equal resource.published_url, resource.url

      resource.guid = "some-other-guid"
      resource.original_url = "http://some/other.filename"
      assert resource.valid?
      refute_equal resource.published_url, resource.url
    end
  end
end
