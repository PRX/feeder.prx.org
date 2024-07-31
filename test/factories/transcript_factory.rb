FactoryBot.define do
  factory :transcript do
    episode
    url { "http://some.where/test/fixtures/sampletranscript.pdf" }
    original_url { "test/fixtures/sampletranscript.pdf" }
    status { "complete" }
    mime_type { "application/pdf" }
  end
end
