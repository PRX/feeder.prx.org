class ItunesCategoryValidator < ActiveModel::Validator
  CATEGORIES = [
    'Arts', 'Business', 'Comedy', 'Education', 'Games &amp; Hobbies',
    'Government &amp; Organizations', 'Health', 'Kids &amp; Family',
    'Music', 'News &amp; Politics', 'Religion &amp; Spirituality',
    'Science &amp; Medicine', 'Society &amp; Culture',
    'Sports &amp; Recreation', 'Technology', 'TV &amp; Film']

  SUBCATEGORIES = ['Design', 'Fashion &amp; Beauty', 'Food', 'Literature', 'Performing Arts', 'Visual Arts',
    'Business News', 'Careers', 'Investing', 'Management &amp; Marketing', 'Shopping', 'Automotive',
    'Aviation', 'Hobbies', 'Other Games', 'Video Games', 'Educational Technology', 'Higher Education',
    'K-12', 'Language Courses', 'Training', 'Local', 'National', 'Non-Profit', 'Regional', 'Alternative Health',
    'Fitness &amp; Nutrition', 'Self-Help', 'Sexuality', 'Buddhism', 'Christianity', 'Hinduism', 'Islam',
    'Judaism', 'Other', 'Spirituality', 'Medicine', 'Natural Sciences', 'Social Sciences', 'History',
    'Personal Journals', 'Philosophy', 'Places &amp; Travel', 'Amateur', 'College &amp; High School',
    'Outdoor', 'Professional', 'Gadgets', 'Podcasting', 'Software How-To', 'Tech News'
  ]

  def validate(record)
    unless record.podcast_id
      record.errors[:podcast_id] << 'Must have an associated podcast'
    end

    validate_category(record)
    validate_subcategories(record)
  end

  def validate_category(record)
    unless CATEGORIES.include?(record.name)
      record.errors[:name] << "#{record.name} is not a valid iTunes category"
    end
  end

  def validate_subcategories(record)
    unless record.subcategories.nil?
      subcats = record.subcategories.split(', ')

      subcats.each do |subcat|
        unless SUBCATEGORIES.include?(subcat)
          record.errors[:subcategories] << "#{subcat} is not a valid iTunes subcategory"
        end
      end
    end
  end
end
