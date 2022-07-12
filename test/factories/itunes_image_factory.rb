FactoryGirl.define do
  factory :itunes_image do
    original_url 'test/fixtures/valid_series_image.jpg'
    width 1400
    height 1400
    size 95314
    status 'complete'
    format 'jpeg'
  end
end
