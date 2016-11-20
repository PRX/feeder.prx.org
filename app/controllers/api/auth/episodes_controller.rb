# encoding: utf-8

class Api::Auth::EpisodesController < Api::EpisodesController
  include ApiAuthenticated
  api_versions :v1

  def scoped(relation)
    relation
  end
end
