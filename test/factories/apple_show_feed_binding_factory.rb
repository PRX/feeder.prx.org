FactoryBot.define do
  factory :apple_show_feed_binding, class: Apple::ShowFeedBinding do
    feed { association(:public_feed) }
    apple_key
    sequence(:apple_show_id) { |n| "show-#{n}" }
  end
end
