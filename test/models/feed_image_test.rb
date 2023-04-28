require "test_helper"

describe FeedImage do
  let(:podcast) { build_stubbed(:podcast) }
  let(:feed) { build_stubbed(:feed, podcast: podcast) }
  let(:image) { build_stubbed(:feed_image, feed: feed) }

  describe "#valid?" do
    it "checks file type when complete" do
      assert image.valid?

      image.format = "bad"
      refute image.valid?
      assert_includes image.errors[:format], "is not included in the list"

      image.status = "invalid"
      assert image.valid?
    end
  end

  describe "#destination_path" do
    it "includes the podcast path" do
      assert_equal "#{podcast.path}/images/#{image.guid}/#{image.file_name}", image.destination_path
    end
  end

  describe "#published_url" do
    it "includes the podcast published url" do
      assert_equal "#{podcast.base_published_url}/images/#{image.guid}/#{image.file_name}", image.published_url
    end
  end
end
