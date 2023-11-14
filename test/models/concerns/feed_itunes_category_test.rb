require "test_helper"

class FeedITunesCategoryTest < ActiveSupport::TestCase
  let(:feed) do
    feed = build_stubbed(:feed)
    feed.itunes_categories.build(name: "Business", subcategories: ["Investing", "Marketing"])
    feed.itunes_categories.build(name: "Arts", subcategories: ["Food"])
    feed.itunes_categories.build(name: "Technology")
    feed
  end

  describe "#itunes_category" do
    it "gets itunes category names" do
      assert_equal ["Business", "Arts", "Technology"], feed.itunes_category
    end

    it "filters nil/destroyed categories" do
      feed.itunes_categories[0].mark_for_destruction
      feed.itunes_categories[1].name = nil
      assert_equal ["Technology"], feed.itunes_category
    end
  end

  describe "#itunes_category=" do
    it "sets itunes categories" do
      feed.itunes_category = ["Arts", "Science"]
      assert_equal ["Arts", "Science"], feed.itunes_category
      assert feed.itunes_categories[0].marked_for_destruction?
      refute feed.itunes_categories[1].marked_for_destruction?
      assert feed.itunes_categories[2].marked_for_destruction?
      refute feed.itunes_categories[3].marked_for_destruction?
    end

    it "leaves a nil category for default feeds" do
      refute feed.default?

      # non-default feeds can destroy all cats
      feed.itunes_category = []
      assert feed.itunes_categories.all?(&:marked_for_destruction?)

      feed.slug = nil
      assert feed.default?

      # default feeds add a new category with nil (invalid) name
      feed.itunes_category = []
      assert feed.itunes_categories[3].new_record?
      assert_nil feed.itunes_categories[3].name

      # but compacts the nil name out of the getter
      assert_equal [], feed.itunes_category
    end
  end

  describe "#itunes_subcategory" do
    it "gets sorted itunes subcategory names" do
      assert_equal ["Food", "Investing", "Marketing"], feed.itunes_subcategory
    end

    it "filters destroyed categories" do
      feed.itunes_categories[0].mark_for_destruction
      assert_equal ["Food"], feed.itunes_subcategory
    end
  end

  describe "#itunes_subcategory=" do
    it "sets itunes subcategories" do
      feed.itunes_subcategory = ["Marketing", "Food", "Performing Arts", "Fitness"]
      assert_equal ["Food", "Marketing", "Performing Arts"], feed.itunes_subcategory
    end
  end

  describe "#itunes_category_options" do
    it "gets the full list of options" do
      opts = feed.itunes_category_options
      assert_equal ITunesCategoryValidator::CATEGORIES.keys.length, opts.length

      # selections are first, followed by alphabetical
      assert_equal ["Business", "Arts", "Technology", "Comedy", "Education"], opts[0..4]
    end
  end

  describe "#itunes_category_map" do
    it "gets the full category-to-subcategory map" do
      assert_equal ITunesCategoryValidator::CATEGORIES, feed.itunes_category_map
    end
  end

  describe "#itunes_subcategory_options" do
    it "gets just your current subcategory options" do
      business = ITunesCategoryValidator::CATEGORIES["Business"]
      arts = ITunesCategoryValidator::CATEGORIES["Arts"]
      technology = ITunesCategoryValidator::CATEGORIES["Technology"]

      assert_equal business + arts + technology, feed.itunes_subcategory_options
    end
  end
end
