FactoryBot.define do
  factory :transcript do
    episode
    url { "http://some.where/test/fixtures/sample_transcript.txt" }
    original_url { "test/fixtures/sample_transcript.txt" }
    status { "complete" }
    format { "txt" }
  end
end
