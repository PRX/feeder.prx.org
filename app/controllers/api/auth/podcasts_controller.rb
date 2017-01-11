# encoding: utf-8

class Api::Auth::PodcastsController < Api::BaseController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::PodcastRepresenter
  after_action :publish, only: [:create, :update, :destroy]

  def show
    return respond_with_error(HalApi::Errors::NotFound.new) if !show_resource
    return respond_with_error(ResourceGone.new) if show_resource.deleted?
    super
  end

  private

  def publish
    resource.publish! if resource
  end

  def scoped(relation)
    relation.with_deleted
  end
end
