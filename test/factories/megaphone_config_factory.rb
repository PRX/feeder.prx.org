FactoryBot.define do
  factory :megaphone_config, class: Megaphone::Config do
    publish_enabled { true }
    sync_blocks_rss { true }
    token { "thisisatokenforacessingtheapi" }
    network_id { "this-is-a-network-id" }
    network_name { "test network" }
    organization_id { "this-is-an-organization-id" }
    feed
  end
end
