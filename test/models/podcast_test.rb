require 'test_helper'

describe Podcast do
  let(:podcast) { create(:podcast) }
  let(:image) { create(:image, imageable: podcast) }

  describe 'associations' do
    it 'has episodes' do
      podcast.must_respond_to(:episodes)
    end

    it 'has an image' do
      image
      podcast.image.must_equal(image)
    end
  end
end
