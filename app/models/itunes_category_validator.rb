class ItunesCategoryValidator < ActiveModel::Validator
  CATEGORIES = {
    "Arts" => ["Design", "Fashion &amp; Beauty", "Food", "Literature", "Performing Arts", "Visual Arts"],
    "Business" => ["Business News", "Careers", "Investing", "Management &amp; Marketing", "Shopping"],
    "Comedy" => [],
    "Education" => ["Education", "Education Technology", "Higher Education", "K-12", "Language Courses", "Training"],
    "Games &amp; Hobbies" => ["Automotive", "Aviation", "Hobbies", "Other Games", "Video Games"],
    "Government &amp; Organizations" => ["Local", "National", "Non-Profit", "Regional"],
    "Health" => ["Alternative Health", "Fitness & Nutrition", "Self-Help", "Sexuality"],
    "Kids &amp; Family" => [],
    "Music" => [],
    "News &amp; Politics" => [],
    "Religion &amp; Spirituality" => ["Buddhism", "Christianity", "Hinduism", "Islam", "Judaism", "Other", "Spirituality"],
    "Science &amp; Medicine" => ["Medicine", "Natural Sciences", "Social Sciences"],
    "Society &amp; Culture" => ["History", "Personal Journals", "Philosophy", "Places &amp; Travel"],
    "Sports &amp; Recreation" => ["Amateur", "College &amp; High School", "Professional"],
    "Technology" => ["Gadgets", "Tech News", "Podcasting", "Software How-To"],
    "TV &amp; Film" => []
  }

  def validate(record)
    unless record.podcast_id
      record.errors[:podcast_id] << 'Must have an associated podcast'
    end

    if CATEGORIES.keys.include?(record.name)
      validate_subcategories(record)
    else
      record.errors[:name] << "#{record.name} is not a valid iTunes category"
    end
  end

  def validate_subcategories(record)
    unless record.subcategories.nil?
      subcats = record.subcategories.split(', ')

      subcats.each do |subcat|
        unless CATEGORIES[record.name].include?(subcat)
          record.errors[:subcategories] << "#{subcat} is not a valid subcategory"
        end
      end
    end
  end
end
