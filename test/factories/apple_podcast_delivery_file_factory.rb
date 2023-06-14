FactoryBot.define do
  factory :apple_podcast_delivery_file, class: Apple::PodcastDeliveryFile do
    transient do
      sequence(:external_id) { |n| "apple_pdf_id_#{n}" }
    end

    after(:build) do |delivery_file, evaluator|
      api_response = build(:podcast_delivery_file_api_response, external_id: evaluator.external_id)
      delivery_file.apple_sync_log = SyncLog.new(external_id: evaluator.external_id, feeder_type: :podcast_delivery_files, **api_response)
    end
  end
end
