require 'test_helper'

class ApplePodcastDeliveryFileTest < ActiveSupport::TestCase
  describe '.get_delivery_file_bridge_params' do
    it 'should format a single bridge param row' do
      assert_equal({
                     request_metadata: {
                       apple_episode_id: 'some-apple-id',
                       podcast_delivery_id: 'podcast-delivery-id'
                     },
                     api_url: 'http://apple', api_parameters: {}
                   },
                   Apple::PodcastDeliveryFile.get_delivery_file_bridge_params('some-apple-id',
                                                                              'podcast-delivery-id',
                                                                              'http://apple'))
    end
  end

  describe '.get_urls_for_delivery_podcast_delivery_files' do
    let(:podcast_delivery_json) do
      { 'request_metadata' => { 'apple_episode_id' => 'apple-episode-id', 'podcast_container_id' => 1 },
        'api_url' => 'https://api.podcastsconnect.apple.com/v1/podcastDeliveries/fd178589-6c75-4439-931b-813ac5ae4ff0/podcastDeliveryFiles',
        'api_parameters' => {},
        'api_response' => { 'ok' => true,
                            'err' => false,
                            'val' =>
                        { 'data' => [{ 'type' => 'podcastDeliveryFiles',
                                       'id' => '1111111111111111111111111' }] } } }
    end
    let(:apple_api) { build(:apple_api) }

    it 'should format a new set of podcast delivery urls' do
      assert_equal ['https://api.podcastsconnect.apple.com/v1/podcastDeliveryFiles/1111111111111111111111111'],
                   Apple::PodcastDeliveryFile.get_urls_for_delivery_podcast_delivery_files(apple_api,
                                                                                           podcast_delivery_json)
    end
  end
end
