require 'test_helper'

describe Image do
  describe 'associations' do
    it 'belongs to a podcast or episode' do
      image = build_stubbed(:image)
      image.must_respond_to(:imageable)
    end
  end

  describe 'validations' do
    it 'is valid when all attributes are present' do
      image = build_stubbed(:image)
      image.must_be(:valid?)
    end

    it 'can have a height, width and description' do
      image = build_stubbed(:image, height: nil, width: nil, description: nil)
      image.must_be(:valid?)
    end

    it 'must have a url' do
      image = build_stubbed(:image, url: nil)
      image.wont_be(:valid?)
    end

    it 'must have a link' do
      image = build_stubbed(:image, link: nil)
      image.wont_be(:valid?)
    end

    it 'must have a title' do
      image = build_stubbed(:image, title: nil)
      image.wont_be(:valid?)
    end
  end
end
