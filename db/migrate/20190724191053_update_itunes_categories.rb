class UpdateITunesCategories < ActiveRecord::Migration
  def change
    ITunesCategories.find_each do |category|
      # 'Arts' sub 'Literature' -> 'Books'
      if category.name == 'Arts' && category.subcategories.include? = 'Literature'
        category.subcategories[category.subcategories.index('Literature')] = 'Books'
        category.save!
      end

      # 'Business' sub 'Business News' -> 'News' sub 'Business News'
      if category.name == 'Business' && category.subcategories.include? = 'Business News'
        category.name = 'News'
        category.subcategories = ['Business News']
        category.save!
      end

      # 'Business' sub 'Management & Marketing' -> 'Management' and 'Marketing'
      if category.name == 'Business' && category.subcategories.include? = 'Management & Marketing'
        category.subcategories[category.subcategories.index('Management & Marketing')] = 'Management'
        category.subcategories.push('Marketing')
        category.save!
      end

      # 'Business' sub 'Shopping' discontinued
      if category.name == 'Business' && category.subcategories.include? = 'Shopping'
        category.subcategories.delete_at(category.subcategories.index('Shopping'))
        category.save!
      end

      # 'Education' sub 'Educational Technology' discontinued
      if category.name == 'Education' && category.subcategories.include? = 'Educational Technology'
        category.subcategories.delete_at(category.subcategories.index('Educational Technology'))
        category.save!
      end

      # 'Education' sub 'Higher Education' discontinued
      if category.name == 'Education' && category.subcategories.include? = 'Higher Education'
        category.subcategories.delete_at(category.subcategories.index('Higher Education'))
        category.save!
      end

      # 'Education' sub 'K-12' discontinued
      if category.name == 'Education' && category.subcategories.include? = 'K-12'
        category.subcategories.delete_at(category.subcategories.index('K-12'))
        category.save!
      end

      # 'Education' sub 'Language Courses' discontinued
      if category.name == 'Education' && category.subcategories.include? = 'Language Courses'
        category.subcategories.delete_at(category.subcategories.index('Language Courses'))
        category.save!
      end

      # 'Education' sub 'Training' discontinued
      if category.name == 'Education' && category.subcategories.include? = 'Training'
        category.subcategories.delete_at(category.subcategories.index('Training'))
        category.save!
      end

      # 'Games & Hobbies' sub 'Other Games' discontinued
      if category.name == 'Games & Hobbies' && category.subcategories.include? = 'Other Games'
        category.subcategories.delete_at(category.subcategories.index('Other Games'))
        category.save!
      end
      
      # 'Games & Hobbbies' -> 'Leisure'
      if category.name == 'Games & Hobbbies'
        category.name = 'Leisure'
        category.save!
      end

      # 'Government & Organizations' sub 'Local' discontinued
      if category.name == 'Government & Organizations' && category.subcategories.include? = 'Local'
        category.subcategories.delete_at(category.subcategories.index('Local'))
        category.save!
      end

      # 'Government & Organizations' sub 'National' discontinued
      if category.name == 'Government & Organizations' && category.subcategories.include? = 'National'
        category.subcategories.delete_at(category.subcategories.index('National'))
        category.save!
      end

      # 'Government & Organizations' sub 'Non-Profit' -> 'Business' sub 'Non-Profit'
      if category.name == 'Government & Organizations' && category.subcategories.include? = 'Non-Profit'
        category.name = 'Business'
        category.subcategories = ['Non-Profit']
        category.save!
      end

      # 'Government & Organizations' sub 'Regional' discontinued
      if category.name == 'Government & Organizations' && category.subcategories.include? = 'Regional'
        category.subcategories.delete_at(category.subcategories.index('Regional'))
        category.save!
      end

      # 'Government & Organizations' -> 'Government'
      if category.name == 'Government & Organizations'
        category.name = 'Government'
        category.save!
      end

      # 'Health' sub 'Self-Help' discontinued
      if category.name == 'Health' && category.subcategories.include? = 'Self-Help'
        category.subcategories.delete_at(category.subcategories.index('Self-Help'))
        category.save!
      end
      
      # 'Health' sub 'Fitness & Nutrition' -> 'Fitness' and 'Nutrition'
      if category.name == 'Health' && category.subcategories.include? = 'Fitness & Nutrition'
        category.subcategories[category.subcategories.index('Fitness & Nutrition')] = 'Fitness'
        category.subcategories.push('Nutrition')
        category.save!
      end

      # 'Health' -> 'Health & Fitness'
      if category.name == 'Games & Hobbbies'
        category.name = 'Leisure'
        category.save!
      end
      
      # 'News & Politics' -> 'News'
      if category.name == 'News'
        category.name = 'News & Politics'
        category.save!
      end

      # 'Religion & Spirituality' sub 'Other' -> 'Religion'
      if category.name == 'Religion & Spirituality' && category.subcategories.include? = 'Other'
        category.subcategories[category.subcategories.index('Other')] = 'Religion'
        category.save!
      end

      # 'Science & Medicine' sub 'Medicine' -> 'Health & Fitness' sub 'Medicine'
      if category.name == 'Science & Medicine' && category.subcategories.include? = 'Medicine'
        category.name = 'Health & Fitness'
        category.subcategories = ['Medicine']
        category.save!
      end

      # 'Science & Medicine' -> 'Science'
      if category.name == 'Science & Medicine'
        say(category.to_s)
        category.name = 'Science'
        category.save!
      end

      # 'Society & Culture' sub 'History' top-level 'History' no subs
      if category.name == 'Society & Culture' && category.subcategories.include? = 'History'
        category.name = 'History'
        category.subcategories = []
        category.save!
      end

      # 'Sports & Recreation' sub 'Amateur' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include? = 'Amateur'
        category.subcategories.delete_at(category.subcategories.index('Amateur'))
        category.save!
      end

      # 'Sports & Recreation' sub 'College & High School' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include? = 'College & High School'
        category.subcategories.delete_at(category.subcategories.index('College & High School'))
        category.save!
      end

      # 'Sports & Recreation' sub 'Outdoor' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include? = 'Outdoor'
        category.subcategories.delete_at(category.subcategories.index('Outdoor'))
        category.save!
      end

      # 'Sports & Recreation' sub 'Professional' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include? = 'Professional'
        category.subcategories.delete_at(category.subcategories.index('Professional'))
        category.save!
      end

      # 'Sports & Recreation' -> 'Sports'
      if category.name == 'Sports & Recreation'
        category.name = 'Sports'
        category.save!
      end

      # 'Technology' sub 'Gadgets' discontinued
      if category.name == 'Technology' && category.subcategories.include? = 'Gadgets'
        category.subcategories.delete_at(category.subcategories.index('Gadgets'))
        category.save!
      end

      # 'Technology' sub 'Tech News' -> 'News' sub 'Tech News'
      if category.name == 'Technology' && category.subcategories.include? = 'Tech News'
        category.name = 'News'
        category.subcategories = ['Tech News']
        category.save!
      end

      # 'Technology' sub 'Podcasting' discontinued
      if category.name == 'Technology' && category.subcategories.include? = 'Podcasting'
        category.subcategories.delete_at(category.subcategories.index('Podcasting'))
        category.save!
      end

      # 'Technology' sub 'Software How-To' discontinued
      if category.name == 'Technology' && category.subcategories.include? = 'Software How-To'
        category.subcategories.delete_at(category.subcategories.index('Software How-To'))
        category.save!
      end
    end
  end
end
