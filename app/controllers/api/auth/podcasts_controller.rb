# encoding: utf-8

class Api::Auth::PodcastsController < Api::PodcastsController
  include ApiAuthenticated
  api_versions :v1
  represent_with Api::PodcastRepresenter

  def scoped(relation)
    relation
  end
end
