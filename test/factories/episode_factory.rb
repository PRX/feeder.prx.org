FactoryGirl.define do
  factory :episode do
    podcast
    sequence(:prx_uri) { |n| "/api/v1/stories/#{(87683 + n)}" }
    sequence(:prx_audio_version_uri) { |n| "/api/v1/audio_versions/#{(484848 + n)}" }

    sequence(:season_number) { |n| n * 2 }
    sequence(:episode_number) { |n| n }
    sequence(:guid) { |n| "ba047dce-9df5-4132-a04b-31d24c7c55a#{n}" }
    sequence(:title) { |n| "Episode #{n}" }
    sequence(:clean_title) { |n| "Clean title #{n}" }
    sequence(:published_at) { |n| Date.today - n.days }

    audio_version "One segment audio"
    segment_count 1

    description "<div><a href='/tina'>Tina</a> McElroy Ansa is a little girl when her father's business goes under and her family must leave their beloved, expansive home.</div>"

    content "<div><a href='/tina'>Tina</a> McElroy Ansa is a little girl when her father's business goes under and her family must leave their beloved, expansive home.</div>"

    summary "<a href='/tina'>Tina</a> McElroy Ansa is a little girl when her father's business goes under and her family must leave their beloved, expansive home."

    after(:create) do |episode, evaluator|
      episode.enclosures << create(:enclosure, episode: episode, status: 'complete')
      episode.images << create(:episode_image, episode: episode, status: 'complete')
    end
  end
end
