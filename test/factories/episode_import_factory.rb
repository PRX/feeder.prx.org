FactoryBot.define do
  factory :episode_import do
    podcast_import
    episode
    guid { "thisisnotaguid" }
  end
end
