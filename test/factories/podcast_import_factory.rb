FactoryGirl.define do
  factory :podcast_import do
    account
    user
    series

    url 'http://feeds.prx.org/transistor_stem'
  end
end
