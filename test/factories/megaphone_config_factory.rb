FactoryBot.define do
  factory :megaphone_config, class: Megaphone::Config do
    token { "thisisatokenforacessingtheapi" }
    network_id { "this-is-a-network-id" }
    feed
  end
end
