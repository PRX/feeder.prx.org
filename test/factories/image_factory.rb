FactoryGirl.define do
  factory :itunes_image do
    original_url 'test/fixtures/valid_series_image.jpg'
    width 1400
    height 1400
    size 95314
    format 'jpeg'
  end

  factory :feed_image do
    original_url 'test/fixtures/valid_feed_image.png'
    link 'http://www.maximumfun.org/jjgo'
    title 'Jordan, Jesse GO!'
    description 'Not a picture of Jordan or Jesse'
    width 144
    height 144
    size 14467
    format 'png'
  end
end
