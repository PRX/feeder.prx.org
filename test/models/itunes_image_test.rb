require 'test_helper'

describe ITunesImage do
  describe 'associations' do
    it 'belongs to a feed' do
      feed = create(:default_feed)
      image = feed.itunes_image

      assert_equal image.feed, feed
    end
  end

  describe 'validations' do
    before do
      @image = build(:itunes_image)
    end

    it 'is valid with correct size and type' do
      assert @image.valid?
    end

    it 'is valid with no size or type' do
      @image = ITunesImage.new(original_url: 'test/fixtures/valid_series_image.png')
      assert @image.valid?
    end

    it 'is invalid without a url' do
      @image.original_url = nil

      refute @image.valid?
    end

    it 'must be a jpg or png' do
      @image.original_url = 'test/fixtures/valid_series_image.png'
      assert @image.valid?

      @image.original_url = 'test/fixtures/wrong_type_image.gif'
      refute @image.valid?
    end

    it 'must be under 2048x2048' do
      @image.original_url = 'test/fixtures/too_big_image.jpg'
      refute @image.valid?
    end

    it 'must be greater than 1400x1400' do
      @image.original_url = "test/fixtures/too_small_image.jpg"

      refute @image.valid?
    end

    it 'must be a square' do
      @image.original_url = "test/fixtures/wrong_proportions_image.jpg"

      refute @image.valid?
    end
  end
end
