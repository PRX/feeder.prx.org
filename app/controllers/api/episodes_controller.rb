class Api::EpisodesController < Api::BaseController
  api_versions :v1
  represent_with Api::EpisodeRepresenter
  filter_resources_by :podcast_id
  find_method :find_by_guid

  def show
    res = show_resource
    if !res || !res.published? || !res.released?
      respond_with_error(HalApi::Errors::NotFound.new)
    elsif res.deleted?
      respond_with_error(ResourceGone.new)
    else
      super
    end
  end

  def scoped(relation)
    relation.with_deleted
  end
end
