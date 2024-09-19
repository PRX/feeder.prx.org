FactoryBot.define do
  factory :transcript do
    episode
    url { "http://some.where/test/fixtures/sampletranscript.txt" }
    original_url { "test/fixtures/sampletranscript.txt" }
    status { "complete" }
    mime_type { "text/plain" }
  end
end
