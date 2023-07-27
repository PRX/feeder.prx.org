require "test_helper"

describe TagListValidator do
  let(:feed) { build(:feed) }

  it "allows nil" do
    feed.include_tags = nil
    assert feed.valid?
  end

  it "compacts empty values to nil" do
    feed.include_tags = {}
    assert_nil feed.include_tags

    feed.include_tags = []
    assert_nil feed.include_tags

    feed.include_tags = [""]
    assert_nil feed.include_tags
  end

  it "validates string tags" do
    feed.include_tags = ["anything", 333]
    refute feed.valid?

    feed.include_tags = ["tag", "tag", Object.new]
    refute feed.valid?

    feed.include_tags = ["tag", "tag with spaces ", "1234"]
    assert feed.valid?
  end

  it "compacts string tags" do
    feed.include_tags = ["", "tag", "tag with spaces", ""]
    assert_equal ["tag", "tag with spaces"], feed.include_tags
  end
end
