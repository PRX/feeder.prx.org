FactoryBot.define do
  factory :episode_import do
    podcast_import
    episode
    entry { HashWithIndifferentAccess.new(entry_id: "thisisnotaguid") }
    guid { "thisisnotaguid" }
  end
end
