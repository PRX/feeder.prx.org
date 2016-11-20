# encoding: utf-8

class Api::AuthorizationRepresenter < Api::BaseRepresenter
  property :user_id, writeable: false

  link :episode do
    {
      href: api_authorization_episode_path_template(id: '{guid}'),
      templated: true,
    }
  end

  def self_url(_r)
    api_authorization_path
  end
end
