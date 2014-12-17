FactoryGirl.define do
  factory :podcast do
    link 'http://www.maximumfun.org/jjgo'
    title 'Jordan, Jesse GO!'
    description 'A goofy fun-time laugh cast with doofuses'
    language 'en-us'
    managing_editor 'Jesse Thorn'
    pub_date Time.now
    last_build_date Time.now
    categories 'Humor, Entertainment'
    explicit true
    subtitle 'Goofy laughsters'
    summary 'Public radio host Jesse Thorn and @midnight writer Jordan Morris goof around'
    keywords 'laffs, comedy, good-times'
    update_period 'weekly'
    update_value 1
    update_base 1.year.ago
  end
end
