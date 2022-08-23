FactoryGirl.define do
  factory :podcast do
    sequence(:prx_uri) { |n| "/api/v1/series/#{n}" }
    sequence(:prx_account_uri) { |n| "/api/v1/accounts/#{n}" }
    sequence(:published_at) { |n| Date.today - n.days }
    path 'jjgo'
    link 'http://www.maximumfun.org/jjgo'
    title 'Jordan, Jesse GO!'
    description 'A goofy fun-time laughcast with doofuses'
    copyright 'Copyright © 2014 Jordan, Jesse GO!. All rights reserved.'
    language 'en-us'
    managing_editor_name 'Jesse Thorn'
    managing_editor_email 'jesse@maximumfun.org'
    author_name 'Jesse Thorn'
    author_email 'jesse@maximumfun.org'
    owner_name 'Jesse Thorn'
    owner_email 'jesse@maximumfun.org'
    categories ['Humor', 'Entertainment']
    explicit 'true'
    subtitle 'Goofy laughsters'
    summary 'Public radio host Jesse Thorn and @midnight writer Jordan Morris goof around'
    keywords ['laffs', 'comedy', 'good-times']
    update_period 'weekly'
    update_frequency 1
    update_base 1.year.ago
    payment_pointer '$alice.example.pointer'

    default_feed
    itunes_image
    feed_image

    after(:create) do |podcast, evaluator|
      itunes_category = create(:itunes_category, podcast: podcast)
      podcast.itunes_categories << itunes_category
    end
  end
end
