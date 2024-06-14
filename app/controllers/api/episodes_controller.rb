class Api::EpisodesController < Api::BaseController
  include ApiUpdatedSince
  include ApiPublishedRange

  api_versions :v1
  represent_with Api::EpisodeRepresenter
  filter_resources_by :podcast_id

  find_method :find_by_guid
  after_action :process_media, only: [:create, :update]
  after_action :publish, only: [:create, :update, :destroy]
  allow_params :show, [:id, :podcast_id, :guid_resource, :api_version, :format, :zoom]

  def included(relation)
    if action_name == "index"
      relation.includes(:podcast, :images, :contents)
    else
      relation
    end
  end

  def create
    res = create_resource
    consume! res, create_options

    if !res.prx_uri.blank? && (existing_res = Episode.find_by(prx_uri: res.prx_uri))
      res = existing_res
      consume! res, create_options
    end

    hal_authorize res
    res.save!
    respond_with root_resource(res), create_options
    res
  end

  def decorate_query(res)
    list_scoped(super(res))
  end

  def list_scoped(res)
    res.in_default_feed
  end

  def show
    super if visible?
  end

  def show_resource
    if params[:guid_resource]
      resource = Episode.find_by_item_guid(params[:id])
      raise HalApi::Errors::NotFound.new if resource.nil?

      @episode = resource
    end

    super
  end

  def visible?
    visible = false
    if !show_resource
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif show_resource.deleted?
      respond_with_error(ResourceGone.new)
    elsif !show_resource.in_default_feed?
      if EpisodePolicy.new(pundit_user, show_resource).update?
        redirect_to api_authorization_episode_path(api_version, show_resource.guid)
      else
        respond_with_error(HalApi::Errors::NotFound.new)
      end
    else
      visible = true
    end
    visible
  end

  def find_base
    super.with_deleted
  end

  def sorted(res)
    res.order(Arel.sql("published_at DESC, id DESC"))
  end

  def process_media
    resource&.copy_media
  end

  def publish
    resource&.publish!
  end
end
