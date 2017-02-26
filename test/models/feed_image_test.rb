require "test_helper"

describe FeedImage do
  let(:image) { build_stubbed(:feed_image) }

  it 'is valid when all attributes are present' do
    image.must_be(:valid?)
  end

  it 'must have an original url' do
    image.original_url = nil

    image.wont_be(:valid?)
    image.errors[:original_url].must_include "can't be blank"
  end

  it 'can have height and width' do
    image.height, image.width = [nil, nil]

    image.must_be(:valid?)
  end

  it 'can have a description' do
    image.description = nil
    image.must_be(:valid?)
  end

  it 'must be a jpg, png, or gif' do
    image.detect_image_attributes
    image.format = 'bmp'
    image.valid?
    image.errors[:format].must_include "is not included in the list"
  end
end
