FactoryBot.define do
  factory :key, class: Apple::Key, aliases: [:apple_key] do
    key_id { "some_key_id" }
    key_pem_b64 { Base64.encode64(test_file("/fixtures/apple_podcasts_connect_keyfile.pem")) }
    provider_id { SecureRandom.uuid }
  end
end
