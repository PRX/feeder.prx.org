FactoryGirl.define do
  factory :episode do
    podcast
    sequence(:prx_uri) { |n| "/api/v1/stories/#{(87683 + n)}" }

    sequence(:guid) { |n| "ba047dce-9df5-4132-a04b-31d24c7c55a#{n}" }
    sequence(:title) { |n| "Episode #{n}" }
    sequence(:published_at) { |n| Date.today + n.days }

    description "Tina McElroy Ansa is a little girl when her father's business goes under and her family must leave their beloved, expansive home."

    content "<div>Tina McElroy Ansa is a little girl when her father&rsquo;s business goes under and her family must leave their beloved, expansive home.</div>"

    summary "<div>Tina McElroy Ansa is a little girl when her father&rsquo;s business goes under and her family must leave their beloved, expansive home.</div>"

    after(:create) do |episode, evaluator|
      enclosure = create(:enclosure, episode: episode, status: 'complete')
      episode.enclosures << enclosure
    end
  end
end
