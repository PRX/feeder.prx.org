require "test_helper"

describe EpisodeImage do
  describe "associations" do
    it "belongs to a episode" do
      episode = create(:episode)
      image = episode.image

      assert_equal image.episode, episode
    end
  end

  describe "copying" do
    let(:image) { create(:episode_image_with_episode) }
    let(:episode) { image.episode }

    it "has a path" do
      assert_equal image.destination_path, "#{episode.podcast.path}/#{image.episode.guid}/images/#{image.guid}/image.png"
    end

    it "has a published url" do
      assert_equal image.published_url, "https://f.prxu.org/#{episode.podcast.path}/#{image.episode.guid}/images/#{image.guid}/image.png"
    end

    it "has a path for episode images" do
      assert_equal image.image_path, "images/#{image.guid}/image.png"
    end
  end

  describe "validations" do
    before do
      @image = build(:itunes_image)
    end

    it "is valid with correct size and type" do
      assert @image.valid?
    end

    it "is valid with no size or type" do
      @image = EpisodeImage.new(original_url: "test/fixtures/valid_series_image.png")
      assert @image.valid?
    end

    it "is invalid without an original url" do
      @image.original_url = nil
      refute @image.valid?
    end

    it "must be a jpg or png" do
      @image.original_url = "test/fixtures/valid_series_image.png"
      assert @image.valid?

      @image.original_url = "test/fixtures/wrong_type_image.gif"
      refute @image.valid?
    end

    it "must be under 3000x3000" do
      @image.original_url = "test/fixtures/too_big_image.jpg"
      refute @image.valid?
    end

    it "must be greater than 1400x1400" do
      @image.original_url = "test/fixtures/too_small_image.jpg"
      refute @image.valid?
    end

    it "must be a square" do
      @image.original_url = "test/fixtures/wrong_proportions_image.jpg"
      refute @image.valid?
    end

    it "can be a large file" do
      @image.original_url = "test/fixtures/offshore-logo-3000.jpg"
      assert @image.valid?
      assert_equal @image.width, 3000
    end

    it "handle fastimage error" do
      stub_request(:get, "http://www.prx.org/fakeimageurl.jpg")
        .to_return(status: 500, body: "", headers: {})

      assert_raises(FastImage::ImageFetchFailure) do
        @image.original_url = "http://www.prx.org/fakeimageurl.jpg"
        @image.valid?
      end
    end
  end
end
