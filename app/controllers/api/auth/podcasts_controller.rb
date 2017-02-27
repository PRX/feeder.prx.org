# encoding: utf-8

class Api::Auth::PodcastsController < Api::BaseController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::PodcastRepresenter
  filter_resources_by :prx_account_uri

  after_action :process_media, only: [:create, :update]
  after_action :publish, only: [:create, :update, :destroy]

  def show
    return respond_with_error(HalApi::Errors::NotFound.new) if !show_resource
    return respond_with_error(ResourceGone.new) if show_resource.deleted?
    super
  end

  private

  def scoped(relation)
    relation.with_deleted
  end

  def process_media
    resource.copy_media if resource
  end

  def publish
    resource.publish! if resource
  end
end
