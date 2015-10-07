class ITunesCategoryValidator < ActiveModel::Validator
  CATEGORIES = {
    "Arts" => ["Design", "Fashion & Beauty", "Food", "Literature", "Performing Arts", "Visual Arts"],
    "Business" => ["Business News", "Careers", "Investing", "Management & Marketing", "Shopping"],
    "Comedy" => [],
    "Education" => ["Education", "Education Technology", "Higher Education", "K-12", "Language Courses", "Training"],
    "Games & Hobbies" => ["Automotive", "Aviation", "Hobbies", "Other Games", "Video Games"],
    "Government & Organizations" => ["Local", "National", "Non-Profit", "Regional"],
    "Health" => ["Alternative Health", "Fitness & Nutrition", "Self-Help", "Sexuality"],
    "Kids & Family" => [],
    "Music" => [],
    "News & Politics" => [],
    "Religion & Spirituality" => ["Buddhism", "Christianity", "Hinduism", "Islam", "Judaism", "Other", "Spirituality"],
    "Science & Medicine" => ["Medicine", "Natural Sciences", "Social Sciences"],
    "Society & Culture" => ["History", "Personal Journals", "Philosophy", "Places & Travel"],
    "Sports & Recreation" => ["Amateur", "College & High School", "Professional"],
    "Technology" => ["Gadgets", "Tech News", "Podcasting", "Software How-To"],
    "TV & Film" => []
  }

  def validate(record)
    if is_category?(record.name)
      validate_subcategories(record)
    else
      record.errors[:name] << "#{record.name} is not a valid iTunes category"
    end
  end

  def validate_subcategories(record)
    record.subcategories.each do |subcat|
      unless is_subcategory?(subcat, record.name)
        record.errors[:subcategories] << "#{subcat} is not a valid subcategory"
      end
    end
  end

  def self.is_category?(cat)
    CATEGORIES.keys.include?(cat)
  end

  def is_category?(cat)
    self.class.is_category?(cat)
  end

  def self.is_subcategory?(subcat, category = nil)
    cat ||= category
    cats = cat ? [cat] : CATEGORIES.keys
    cats.each do |c|
      return c if CATEGORIES[c].include?(subcat)
    end
    nil
  end

  def is_subcategory?(subcat, cat = nil)
    self.class.is_subcategory?(subcat, cat)
  end
end
