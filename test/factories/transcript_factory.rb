FactoryBot.define do
  factory :transcript do
    episode
    url { "http://some.where/test/fixtures/sampletranscript.html" }
    original_url { "test/fixtures/sampletranscript.html" }
    status { "complete" }
    mime_type { "text/html" }
    format { "html" }
  end
end
