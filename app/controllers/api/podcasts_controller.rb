# encoding: utf-8

class Api::PodcastsController < Api::BaseController
  api_versions :v1
  represent_with Api::PodcastRepresenter
  after_action :publish, only: [:create, :update, :destroy]
  filter_resources_by :prx_account_uri

  def show
    return respond_with_error(HalApi::Errors::NotFound.new) if !show_resource
    return respond_with_error(ResourceGone.new) if show_resource.deleted?
    return super if show_resource.published?

    if PodcastPolicy.new(pundit_user, show_resource).update?
      redirect_to api_authorization_podcast_path(api_version, show_resource)
    else
      respond_with_error(HalApi::Errors::NotFound.new)
    end
  end

  private

  def publish
    resource.publish! if resource
  end

  def scoped(relation)
    relation.with_deleted
  end
end
