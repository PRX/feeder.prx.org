require "test_helper"

describe TagListValidator do
  let(:feed) { build(:feed) }

  it "allows nil" do
    feed.include_tags = nil
    assert feed.valid?

    feed.include_tags = {}
    refute feed.valid?

    feed.include_tags = []
    refute feed.valid?
  end

  it "validates string tags" do
    feed.include_tags = ["anything", 333]
    refute feed.valid?

    feed.include_tags = ["tag", "tag", Object.new]
    refute feed.valid?

    feed.include_tags = ["tag", "tag with spaces ", "1234"]
    assert feed.valid?
  end
end
