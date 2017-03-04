require 'test_helper'

describe EpisodeImage do
  describe 'associations' do
    it 'belongs to a episode' do
      episode = create(:episode)
      image = episode.image

      image.episode.must_equal episode
    end
  end

  describe 'copying' do
    let (:image) { create(:episode_image_with_episode) }
    let (:episode) { image.episode }

    it 'has a path' do
      image.destination_path.must_equal "jjgo/#{image.episode.guid}/images/#{image.guid}/image.png"
    end

    it 'has a published url' do
      image.published_url.must_equal "https://f.prxu.org/jjgo/#{image.episode.guid}/images/#{image.guid}/image.png"
    end

    it 'has a path for episode images' do
      image.image_path.must_equal "images/#{image.guid}/image.png"
    end

    it 'updates from fixer callback' do
      old_image = create(:episode_image_with_episode, episode: episode, created_at: 1.year.ago)
      episode.images.must_be :include?, old_image
      image.url.must_be_nil
      image.update_from_fixer({})
      image.url.must_equal image.published_url
      episode.images(true).wont_be :include?, old_image
    end
  end

  describe 'validations' do
    before do
      @image = build(:itunes_image)
    end

    it 'is valid with correct size and type' do
      @image.must_be :valid?
    end

    it 'is valid with no size or type' do
      @image = EpisodeImage.new(original_url: 'test/fixtures/valid_series_image.png')
      @image.must_be :valid?
    end

    it 'is invalid without an original url' do
      @image.original_url = nil
      @image.wont_be :valid?
    end

    it 'must be a jpg or png' do
      @image.original_url = 'test/fixtures/valid_series_image.png'
      @image.must_be :valid?

      @image.original_url = 'test/fixtures/wrong_type_image.gif'
      @image.wont_be :valid?
    end

    it 'must be under 3000x3000' do
      @image.original_url = 'test/fixtures/too_big_image.jpg'
      @image.wont_be :valid?
    end

    it 'must be greater than 1400x1400' do
      @image.original_url = 'test/fixtures/too_small_image.jpg'
      @image.wont_be :valid?
    end

    it 'must be a square' do
      @image.original_url = 'test/fixtures/wrong_proportions_image.jpg'
      @image.wont_be :valid?
    end

    it 'can be a large file' do
      @image.original_url = 'test/fixtures/offshore-logo-3000.jpg'
      @image.must_be :valid?
      @image.width.must_equal 3000
    end
  end
end
