class UpdateITunesCategories < ActiveRecord::Migration
  def up
    ITunesCategory.find_each do |category|
      # 'Arts' sub 'Literature' -> 'Books'
      if category.name == 'Arts' && category.subcategories.include?('Literature')
        category.subcategories[category.subcategories.index('Literature')] = 'Books'
      end

      # 'Business' sub 'Business News' -> 'News' sub 'Business News'
      if category.name == 'Business' && category.subcategories.include?('Business News')
        category.name = 'News'
        category.subcategories = ['Business News']
      end

      # 'Business' sub 'Management & Marketing' -> 'Management' and 'Marketing'
      if category.name == 'Business' && category.subcategories.include?('Management & Marketing')
        category.subcategories[category.subcategories.index('Management & Marketing')] = 'Management'
        category.subcategories.push('Marketing')
      end

      # 'Business' sub 'Shopping' discontinued
      if category.name == 'Business' && category.subcategories.include?('Shopping')
        category.subcategories.delete_at(category.subcategories.index('Shopping'))
      end

      # 'Education' sub 'Educational Technology' discontinued
      if category.name == 'Education' && category.subcategories.include?('Educational Technology')
        category.subcategories.delete_at(category.subcategories.index('Educational Technology'))
      end

      # 'Education' sub 'Higher Education' discontinued
      if category.name == 'Education' && category.subcategories.include?('Higher Education')
        category.subcategories.delete_at(category.subcategories.index('Higher Education'))
      end

      # 'Education' sub 'K-12' discontinued
      if category.name == 'Education' && category.subcategories.include?('K-12')
        category.subcategories.delete_at(category.subcategories.index('K-12'))
      end

      # 'Education' sub 'Language Courses' discontinued
      if category.name == 'Education' && category.subcategories.include?('Language Courses')
        category.subcategories.delete_at(category.subcategories.index('Language Courses'))
      end

      # 'Education' sub 'Training' discontinued
      if category.name == 'Education' && category.subcategories.include?('Training')
        category.subcategories.delete_at(category.subcategories.index('Training'))
      end

      # 'Games & Hobbies' sub 'Other Games' discontinued
      if category.name == 'Games & Hobbies' && category.subcategories.include?('Other Games')
        category.subcategories.delete_at(category.subcategories.index('Other Games'))
      end
      
      # 'Games & Hobbbies' -> 'Leisure'
      if category.name == 'Games & Hobbbies'
        category.name = 'Leisure'
      end

      # 'Government & Organizations' sub 'Local' discontinued
      if category.name == 'Government & Organizations' && category.subcategories.include?('Local')
        category.subcategories.delete_at(category.subcategories.index('Local'))
      end

      # 'Government & Organizations' sub 'National' discontinued
      if category.name == 'Government & Organizations' && category.subcategories.include?('National')
        category.subcategories.delete_at(category.subcategories.index('National'))
      end

      # 'Government & Organizations' sub 'Non-Profit' -> 'Business' sub 'Non-Profit'
      if category.name == 'Government & Organizations' && category.subcategories.include?('Non-Profit')
        category.name = 'Business'
        category.subcategories = ['Non-Profit']
      end

      # 'Government & Organizations' sub 'Regional' discontinued
      if category.name == 'Government & Organizations' && category.subcategories.include?('Regional')
        category.subcategories.delete_at(category.subcategories.index('Regional'))
      end

      # 'Government & Organizations' -> 'Government'
      if category.name == 'Government & Organizations'
        category.name = 'Government'
      end

      # 'Health' sub 'Self-Help' discontinued
      if category.name == 'Health' && category.subcategories.include?('Self-Help')
        category.subcategories.delete_at(category.subcategories.index('Self-Help'))
      end
      
      # 'Health' sub 'Fitness & Nutrition' -> 'Fitness' and 'Nutrition'
      if category.name == 'Health' && category.subcategories.include?('Fitness & Nutrition')
        category.subcategories[category.subcategories.index('Fitness & Nutrition')] = 'Fitness'
        category.subcategories.push('Nutrition')
      end

      # 'Health' -> 'Health & Fitness'
      if category.name == 'Health'
        category.name = 'Health & Fitness'
      end
      
      # 'News & Politics' -> 'News'
      if category.name == 'News & Politics'
        category.name = 'News'
      end

      # 'Religion & Spirituality' sub 'Other' -> 'Religion'
      if category.name == 'Religion & Spirituality' && category.subcategories.include?('Other')
        category.subcategories[category.subcategories.index('Other')] = 'Religion'
      end

      # 'Science & Medicine' sub 'Medicine' -> 'Health & Fitness' sub 'Medicine'
      if category.name == 'Science & Medicine' && category.subcategories.include?('Medicine')
        category.name = 'Health & Fitness'
        category.subcategories = ['Medicine']
      end

      # 'Science & Medicine' -> 'Science'
      if category.name == 'Science & Medicine'
        category.name = 'Science'
      end

      # 'Society & Culture' sub 'History' top-level 'History' no subs
      if category.name == 'Society & Culture' && category.subcategories.include?('History')
        category.name = 'History'
        category.subcategories = []
      end

      # 'Sports & Recreation' sub 'Amateur' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include?('Amateur')
        category.subcategories.delete_at(category.subcategories.index('Amateur'))
      end

      # 'Sports & Recreation' sub 'College & High School' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include?('College & High School')
        category.subcategories.delete_at(category.subcategories.index('College & High School'))
      end

      # 'Sports & Recreation' sub 'Outdoor' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include?('Outdoor')
        category.subcategories.delete_at(category.subcategories.index('Outdoor'))
      end

      # 'Sports & Recreation' sub 'Professional' discontinued
      if category.name == 'Sports & Recreation' && category.subcategories.include?('Professional')
        category.subcategories.delete_at(category.subcategories.index('Professional'))
      end

      # 'Sports & Recreation' -> 'Sports'
      if category.name == 'Sports & Recreation'
        category.name = 'Sports'
      end

      # 'Technology' sub 'Gadgets' discontinued
      if category.name == 'Technology' && category.subcategories.include?('Gadgets')
        category.subcategories.delete_at(category.subcategories.index('Gadgets'))
      end

      # 'Technology' sub 'Tech News' -> 'News' sub 'Tech News'
      if category.name == 'Technology' && category.subcategories.include?('Tech News')
        category.name = 'News'
        category.subcategories = ['Tech News']
      end

      # 'Technology' sub 'Podcasting' discontinued
      if category.name == 'Technology' && category.subcategories.include?('Podcasting')
        category.subcategories.delete_at(category.subcategories.index('Podcasting'))
      end

      # 'Technology' sub 'Software How-To' discontinued
      if category.name == 'Technology' && category.subcategories.include?('Software How-To')
        category.subcategories.delete_at(category.subcategories.index('Software How-To'))
      end

      # Rules for specific Podcasts
      # Sidedoor(50) and AirSpace(111) -> 'History'
      if category.podcast_id == 50 || category.podcast_id == 111
        category.name = 'History'
      end
      # HowSound(223) to 'Education' sub 'How To'
      if category.podcast_id == 223
        category.name = 'Education'
        category.subcategories = ['How To']
      end
      # Outside Podcast(210) to 'Sports' sub 'Wilderness'
      if category.podcast_id == 210
        category.name = 'Sports'
        category.subcategories = ['Wilderness']
      end
      # Scene on Radio(153) to 'Society & Culture'
      if category.podcast_id == 153
        category.name = 'Society & Culture'
      end
      # Second Wave(88) to 'Society & Culture' sub 'Personal Journals'
      if category.podcast_id == 88
        category.name = 'Society & Culture'
        category.subcategories = ['Personal Journals']
      end

      if category.changed?
        puts "updated category[#{category.id}] for podcast[#{category.podcast_id}] => #{category.changes}"
        category.save!
      end
    end
  end

  def down
    puts "No going back"
  end
end
