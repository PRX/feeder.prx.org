require "test_helper"

describe EpisodeImage do
  let(:episode) { build_stubbed(:episode) }
  let(:image) { build_stubbed(:episode_image, episode: episode) }

  describe "#valid?" do
    it "checks file type when complete" do
      assert image.valid?

      image.format = "bad"
      refute image.valid?
      assert_includes image.errors[:format], "is not included in the list"

      image.status = "invalid"
      assert image.valid?
    end

    it "checks image height when completed" do
      assert image.valid?

      image.height = 1399
      refute image.valid?
      assert_includes image.errors[:height], "must be greater than or equal to 1400"

      image.height = 3001
      refute image.valid?
      assert_includes image.errors[:height], "must be less than or equal to 3000"

      image.status = "invalid"
      assert image.valid?
    end

    it "checks image squareness when completed" do
      assert image.valid?
      assert_equal 1400, image.height

      image.width = 1401
      refute image.valid?
      assert_includes image.errors[:width], "must be equal to 1400"

      image.status = "invalid"
      assert image.valid?
    end
  end

  describe "#destination_path" do
    it "includes the episode path" do
      assert_equal "#{episode.path}/images/#{image.guid}/#{image.file_name}", image.destination_path
    end
  end

  describe "#published_url" do
    it "includes the episode published url" do
      assert_equal "#{episode.base_published_url}/images/#{image.guid}/#{image.file_name}", image.published_url
    end
  end
end
