class Api::Auth::PodcastsController < Api::PodcastsController
  include ApiAuthenticated
  include ApiUpdatedSince

  api_versions :v1
  represent_with Api::Auth::PodcastRepresenter
  filter_resources_by :prx_account_uri

  def visible?
    visible = false
    if !show_resource
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif show_resource.deleted?
      respond_with_error(ResourceGone.new)
    else
      visible = true
    end
    visible
  end

  def resources_base
    super.merge(authorization.token_auth_podcasts)
  end

  def filtered(resources)
    if params[:q].present?
      super.filter_by_title(params[:q])
    else
      super
    end
  end
end
