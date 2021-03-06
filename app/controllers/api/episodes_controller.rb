# encoding: utf-8

class Api::EpisodesController < Api::BaseController
  include ApiUpdatedSince

  api_versions :v1
  represent_with Api::EpisodeRepresenter
  find_method :find_by_guid
  filter_resources_by :podcast_id

  after_action :process_media, only: [:create, :update]
  after_action :publish, only: [:create, :update, :destroy]

  def included(relation)
    if action_name == 'index'
      relation.includes(:podcast, :images, :all_contents, :contents, :enclosures)
    else
      relation
    end
  end

  def create
    res = create_resource
    consume! res, create_options

    if !res.prx_uri.blank? && existing_res = Episode.find_by(prx_uri: res.prx_uri)
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
    res.published
  end

  def show
    super if visible?
  end

  def visible?
    visible = false
    if !show_resource
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif show_resource.deleted?
      respond_with_error(ResourceGone.new)
    elsif !show_resource.published?
      if EpisodePolicy.new(pundit_user, show_resource).update?
        redirect_to api_authorization_episode_path(api_version, show_resource)
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
    res.order('published_at DESC, id DESC')
  end

  def process_media
    resource.copy_media if resource
  end

  def publish
    resource.podcast.publish! if resource && resource.podcast
  end
end
