FactoryBot.define do
  factory :stream_recording do
    url { "https://some.where/the/stream.aac" }
    status { "enabled" }
    start_date { 10.days.ago }
    end_date { nil }
    record_days { [1, 3] }
    record_hours { [15, 16, 17] }
    create_as { "clips" }
    expiration { 2592000 }
  end
end
