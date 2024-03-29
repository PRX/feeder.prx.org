class ITunesCategoryValidator < ActiveModel::Validator
  CATEGORIES = {
    "Arts" => ["Books", "Design", "Fashion & Beauty", "Food", "Performing Arts", "Visual Arts"],
    "Business" => ["Careers", "Entrepreneurship", "Investing", "Management", "Marketing", "Non-Profit"],
    "Comedy" => ["Comedy Interviews", "Improv", "Stand-Up"],
    "Education" => ["Courses", "How To", "Language Learning", "Self-Improvement"],
    "Fiction" => ["Comedy Fiction", "Drama", "Science Fiction"],
    "Government" => [],
    "History" => [],
    "Health & Fitness" => ["Alternative Health", "Fitness", "Medicine", "Mental Health", "Nutrition", "Sexuality"],
    "Kids & Family" => ["Education for Kids", "Parenting", "Pets & Animals", "Stories for Kids"],
    "Leisure" => ["Animation & Manga", "Automotive", "Aviation", "Crafts", "Games", "Hobbies", "Home & Garden", "Video Games"],
    "Music" => ["Music Commentary", "Music History", "Music Interviews"],
    "News" => ["Business News", "Daily News", "Entertainment News", "News Commentary", "Politics", "Sports News", "Tech News"],
    "Religion & Spirituality" => ["Buddhism", "Christianity", "Hinduism", "Islam", "Judaism", "Religion", "Spirituality"],
    "Science" => ["Astronomy", "Chemistry", "Earth Sciences", "Life Sciences", "Mathematics", "Natural Sciences", "Nature", "Physics", "Social Sciences"],
    "Society & Culture" => ["Documentary", "Personal Journals", "Philosophy", "Places & Travel", "Relationships"],
    "Sports" => ["Baseball", "Basketball", "Cricket", "Fantasy Sports", "Football", "Golf", "Hockey", "Rugby", "Running", "Soccer", "Swimming", "Tennis", "Volleyball", "Wilderness", "Wrestling"],
    "Technology" => [],
    "True Crime" => [],
    "TV & Film" => ["After Shows", "Film History", "Film Interviews", "Film Reviews", "TV Reviews"]
  }.freeze

  def validate(record)
    return unless record.name.present?

    if category?(record.name)
      validate_subcategories(record)
    else
      record.errors.add :name, :invalid, message: "#{record.name} is not a valid iTunes category"
    end
  end

  def validate_subcategories(record)
    record.subcategories.each do |subcat|
      unless subcategory?(subcat, record.name)
        record.errors.add :subcategories, :invalid, message: "#{subcat} is not a valid subcategory"
      end
    end
  end

  def self.category?(cat)
    CATEGORIES.key?(cat)
  end

  def category?(cat)
    self.class.category?(cat)
  end

  def self.subcategory?(subcat, category = nil)
    cat ||= category
    cats = cat ? [cat] : CATEGORIES.keys
    cats.each do |c|
      return c if CATEGORIES[c].include?(subcat)
    end
    nil
  end

  def subcategory?(subcat, cat = nil)
    self.class.subcategory?(subcat, cat)
  end
end
