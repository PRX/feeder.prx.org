class Api::PodcastsController < Api::BaseController
  include ApiUpdatedSince

  api_versions :v1
  represent_with Api::PodcastRepresenter
  filter_resources_by :prx_account_uri

  after_action :process_media, only: [:create, :update]
  after_action :publish, only: [:create, :update, :destroy]

  def included(relation)
    relation.includes(default_feed: [:itunes_categories, :itunes_images, :feed_images])
  end

  def show
    if visible?
      if request.format.rss?
        render plain: FeedBuilder.new(show_resource).to_feed_xml
      else
        super
      end
    end
  end

  def visible?
    visible = false
    if !show_resource
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif show_resource.deleted?
      respond_with_error(ResourceGone.new)
    elsif !show_resource.published?
      if PodcastPolicy.new(pundit_user, show_resource).update?
        redirect_to api_authorization_podcast_path(api_version, show_resource)
      else
        respond_with_error(HalApi::Errors::NotFound.new)
      end
    else
      visible = true
    end

    visible
  end

  private

  def show_resource
    if params[:series_id]
      resource = Podcast.find_by(prx_uri: "/api/v1/series/#{params[:series_id]}")
      raise HalApi::Errors::NotFound.new if resource.nil?

      @podcast = resource
    end

    super
  end

  def find_base
    super.with_deleted
  end

  def process_media
    resource&.copy_media
  end

  def publish
    resource&.publish!
  end
end
