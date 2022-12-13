FactoryBot.define do
  factory :feed_image do
    url { 'test/fixtures/valid_feed_image.png' }
    original_url { 'test/fixtures/valid_feed_image.png' }
    link { 'http://www.maximumfun.org/jjgo' }
    title { 'Jordan, Jesse GO!' }
    description { 'Not a picture of Jordan or Jesse' }
    width { 144 }
    height { 144 }
    size { 14467 }
    status { 'complete' }
    format { 'png' }
  end
end
