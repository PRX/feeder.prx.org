FactoryBot.define do
  factory :apple_show, class: Apple::Show do
    skip_create

    transient do
      api { build(:apple_api) }
      podcast { create(:podcast) }
      private_feed { create(:private_feed, podcast: podcast) }
      public_feed { podcast.default_feed }
      apple_show_id { "show-1" }
      show_feed_binding { build(:apple_show_feed_binding, feed: public_feed, apple_show_id: apple_show_id) }
    end

    initialize_with do
      new(api: api, public_feed: public_feed, private_feed: private_feed, show_feed_binding: show_feed_binding)
    end
  end
end
