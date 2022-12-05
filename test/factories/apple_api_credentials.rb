require "ostruct"

FactoryGirl.define do
  factory :apple_api_credentials, class: OpenStruct do
    provider_id { SecureRandom.uuid }
    key { test_file("/fixtures/apple_podcasts_connect_keyfile.pem") }
    key_id { "some_key_id" }
  end
end
