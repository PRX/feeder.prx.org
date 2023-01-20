class Api::Auth::FeedsController < Api::BaseController
  api_versions :v1
  represent_with Api::Auth::FeedRepresenter
  filter_resources_by :podcast_id

  after_action :publish, only: [:create, :update, :destroy]

  def publish
    resource.podcast.publish! if resource&.podcast
  end
end
