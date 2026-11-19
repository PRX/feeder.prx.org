require "test_helper"

describe ApplicationHelper do
  let(:helper) { Class.new { include ApplicationHelper }.new }
  let(:podcast) { create(:podcast) }

  describe "#field_state_class" do
    it "is blank for unchanged valid fields" do
      assert_nil helper.field_state_class(podcast, :title)
    end

    it "marks changed fields" do
      podcast.title = "Changed"
      assert_equal "is-changed", helper.field_state_class(podcast, :title)
    end

    it "marks invalid fields" do
      podcast.errors.add(:title, :invalid)
      assert_equal "is-invalid", helper.field_state_class(podcast, :title)

      podcast.title = ""
      assert_equal "is-changed is-invalid", helper.field_state_class(podcast, :title)
    end
  end
end
