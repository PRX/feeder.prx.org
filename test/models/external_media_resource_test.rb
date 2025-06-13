require "test_helper"

describe ExternalMediaResource do
  let(:episode) { create(:episode, external_media_resource: media, enclosure_override_url: media.original_url) }
  let(:media) { build(:external_media_resource) }

  describe "#validate_episode_medium" do
    it "does not have a guid" do
      assert_nil media.guid
    end

    it "urls are the same as original" do
      assert_equal media.url, media.original_url
      assert_equal media.media_url, media.original_url
    end

    it "analyzes the external media" do
      Tasks::AnalyzeMediaTask.stub_any_instance(:porter_start!, true) do
        media.analyze_media
        media.reload
        task = media.task
        assert task.is_a?(Tasks::AnalyzeMediaTask)
        assert_equal task.options["Source"]["URL"], "https://prx.org/audio.mp3"
        assert_equal task.options["Tasks"].first["Type"], "Inspect"
      end
    end
  end
end
