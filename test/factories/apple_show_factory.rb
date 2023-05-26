FactoryBot.define do
  factory :apple_show, class: Apple::Show do
    api { build(:apple_api) }

    transient do
      podcast { nil }
      public_feed { nil }
      private_feed { nil }
    end

    after(:build) do |show, evaluator|
      podcast =
        if evaluator.podcast.nil?
          create(:podcast)
        else
          evaluator.podcast
        end

      show["private_feed"] = evaluator.private_feed || create(:private_feed, podcast: podcast)
      show["public_feed"] = evaluator.private_feed || podcast.default_feed
    end
    initialize_with { attributes }
  end
end
