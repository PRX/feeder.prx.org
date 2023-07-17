FactoryBot.define do
  factory :podcast_container_api_response, class: OpenStruct do
    transient do
      podcast_container_id { "podcast-delivery-id" }
      vendor_id { "43434343" }
      file_name { "some.mp3" }
      file_type { "audio" }
      file_asset_token { "some-token" }
      file_status { "In Asset Repository" }
      file_asset_role { "PodcastSourceAudio" }
    end

    skip_create

    after(:build) do |response_container, evaluator|
      response_container["api_response"] = {"request_metadata" => {},
       "api_url" => "https://api.podcastsconnect.apple.com/v1/podcastContainers/#{evaluator.podcast_container_id}",
       "api_parameters" => {},
       "api_response" =>
       {"ok" => true,
        "err" => false,
        "val" =>
         {"data" =>
         {"type" => "podcastContainers",
          "id" => evaluator.podcast_container_id.to_s,
          "attributes" =>
          {"vendorId" => evaluator.vendor_id.to_s,
           "episodeDetail" => nil,
           "files" =>
            [{"assetToken" => evaluator.file_asset_token.to_s, "fileName" => evaluator.file_name.to_s, "fileType" => evaluator.file_type.to_s, "status" => evaluator.file_status.to_s, "assetRole" => evaluator.file_asset_role.to_s, "imageAsset" => nil}]},
          "relationships" =>
          {"podcastDeliveries" =>
            {"links" =>
              {"self" => "https://api.podcastsconnect.apple.com/v1/podcastContainers/#{evaluator.podcast_container_id}/relationships/podcastDeliveries",
               "related" => "https://api.podcastsconnect.apple.com/v1/podcastContainers/#{evaluator.podcast_container_id}/podcastDeliveries",
               "include" => "https://api.podcastsconnect.apple.com/v1/podcastContainers/#{evaluator.podcast_container_id}?include=podcastDeliveries"}}},
          "links" => {"self" => "https://api.podcastsconnect.apple.com/v1/podcastContainers/#{evaluator.podcast_container_id}"}},
          "links" => {"self" => "https://api.podcastsconnect.apple.com/v1/podcastContainers/#{evaluator.podcast_container_id}"}}}}
      response_container
    end

    initialize_with { attributes }
  end
end
