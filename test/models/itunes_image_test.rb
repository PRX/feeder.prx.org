require 'test_helper'

describe ITunesImage do
  describe 'associations' do
    it 'belongs to a podcast' do
      podcast = build_stubbed(:podcast)
      image = podcast.itunes_image

      image.podcast.must_equal podcast
    end
  end

  describe 'validations' do
    before do
      @image = build(:itunes_image)
    end

    it 'is valid with correct size and type' do
      @image.must_be(:valid?)
    end

    it 'is invalid without a url' do
      @image.url = nil

      @image.wont_be(:valid?)
    end

    it 'must be a jpg or png' do
      @image.url = 'test/fixtures/valid_series_image.png'
      @image.must_be(:valid?)

      @image.url = 'test/fixtures/wrong_type_image.gif'
      @image.wont_be(:valid?)
    end

    it 'must be under 2048x2048' do
      @image.url = 'test/fixtures/too_big_image.jpg'
      @image.wont_be(:valid?)
    end

    it 'must be greater than 1400x1400' do
      @image.url = "test/fixtures/too_small_image.jpg"

      @image.wont_be(:valid?)
    end

    it 'must be a square' do
      @image.url = "test/fixtures/wrong_proportions_image.jpg"

      @image.wont_be(:valid?)
    end
  end
end
