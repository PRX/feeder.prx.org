FactoryGirl.define do
  factory :podcast do
    sequence(:prx_uri) { |n| "/api/v1/series/#{n}" }
    path 'jjgo'
    url 'http://feeds.feedburner.com/thornmorris'
    link 'http://www.maximumfun.org/jjgo'
    title 'Jordan, Jesse GO!'
    description 'A goofy fun-time laughcast with doofuses'
    copyright 'Copyright © 2014 Jordan, Jesse GO!. All rights reserved.'
    language 'en-us'
    managing_editor 'Jesse Thorn'
    author_name 'Jesse Thorn'
    author_email 'jesse@maximumfun.org'
    owner_name 'Jesse Thorn'
    owner_email 'jesse@maximumfun.org'
    pub_date Date.parse("Jan 11, 2015")
    last_build_date Date.parse("Jan 12, 2015")
    categories 'Humor, Entertainment'
    explicit true
    subtitle 'Goofy laughsters'
    summary 'Public radio host Jesse Thorn and @midnight writer Jordan Morris goof around'
    keywords 'laffs, comedy, good-times'
    update_period 'weekly'
    update_value 1
    update_base 1.year.ago

    itunes_image
    feed_image
  end
end
