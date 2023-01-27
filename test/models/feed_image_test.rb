require "test_helper"

describe FeedImage do
  let(:image) { build_stubbed(:feed_image) }

  it "is valid when all attributes are present" do
    assert image.valid?
  end

  it "must have an original url" do
    image.original_url = nil

    refute image.valid?
    assert_includes image.errors[:original_url], "can't be blank"
  end

  it "can have height and width" do
    image.height, image.width = [nil, nil]

    assert image.valid?
  end

  it "must be a jpg, png, or gif" do
    image.detect_image_attributes
    image.format = "bmp"
    image.valid?
    assert_includes image.errors[:format], "is not included in the list"
  end
end
