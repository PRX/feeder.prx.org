class Api::Auth::FeedsController < Api::BaseController
  include ApiAuthenticated

  api_versions :v1
  represent_with Api::Auth::FeedRepresenter
  filter_resources_by :podcast_id

  after_action :publish, only: [:create, :update, :destroy]

  def publish
    resource.podcast.publish! if resource&.podcast
  end

  def resources_base
    @feeds ||= super.merge(authorization.token_auth_feeds)
  end
end
