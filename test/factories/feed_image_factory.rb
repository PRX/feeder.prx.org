FactoryBot.define do
  factory :feed_image do
    url { 'test/fixtures/valid_feed_image.png' }
    original_url { 'test/fixtures/valid_feed_image.png' }
    alt_text { 'valid feed image' }
    caption { 'just look at those things' }
    credit { 'feeder' }
    width { 144 }
    height { 144 }
    size { 14467 }
    status { 'complete' }
    format { 'png' }
  end
end
