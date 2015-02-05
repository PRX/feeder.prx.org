FactoryGirl.define do
  factory :itunes_image do
    url 'test/fixtures/valid_series_image.jpg'
  end

  factory :feed_image do
    url 'test/fixtures/valid_feed_image.png'
    link 'http://www.maximumfun.org/jjgo'
    title '99pi'
    description 'Not a picture of Jordan or Jesse'
  end
end
