require "test_helper"

describe AlternateMediaResource do
  let(:ep) { build_stubbed(:episode) }

  describe "#file_name" do
    it "uses an m3u8 file extension" do
      media = ep.build_alternate_media_resource(original_url: "http://some.where/file.mp4")
      # media.initialize_attributes

      assert_equal "file.m3u8", media.file_name
      assert_equal "#{ep.base_published_url}/#{media.guid}.m3u8", media.url
    end
  end
end
