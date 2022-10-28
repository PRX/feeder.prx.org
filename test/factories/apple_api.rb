FactoryGirl.define do
  factory :apple_api, class: Apple::Api do
    provider_id { SecureRandom.uuid }

    transient do
      key { test_file("/fixtures/apple_podcasts_connect_keyfile.pem") }
      key_id { "some_key_id" }
    end

    after(:build) do |api, evaluator|
      api.key = evaluator.key
      api.key_id = evaluator.key_id
    end
  end
end
