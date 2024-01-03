class Api::Auth::FeedsController < Api::BaseController
  include ApiAuthenticated

  api_versions :v1
  represent_with Api::Auth::FeedRepresenter
  filter_resources_by :podcast_id

  after_action :publish, only: [:create, :update, :destroy]
  allow_params :index, [:format, :api_version, :podcast_id, :page, :per]

  def publish
    resource.podcast.publish! if resource&.podcast
  end

  def included(relation)
    relation.includes(:podcast, :feed_images, :itunes_images, :feed_tokens)
  end

  def resources_base
    authorization.token_auth_feeds
  end
end
