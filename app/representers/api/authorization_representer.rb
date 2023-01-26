class Api::AuthorizationRepresenter < Api::BaseRepresenter
  property :user_id, writeable: false

  link :episodes do
    {
      title: "Get a paged collection of authorized episodes",
      profile: profile_url(:collection, :episode),
      href: api_authorization_episodes_path + "{?page,per,zoom,since}",
      templated: true,
      count: represented.token_auth_episodes.count
    }
  end

  link :episode do
    {
      title: "Get a single authorized episode",
      profile: profile_url(:episode),
      href: api_authorization_episode_path_template(id: "{id}") + "{?zoom}",
      templated: true
    }
  end

  link :guid do
    {
      title: "Get a single episode by item guid",
      profile: profile_url(:episode),
      href: api_authorization_podcast_guid_path_template(podcast_id: "{id}", id: "{guid}"),
      templated: true
    }
  end

  link :podcasts do
    {
      title: "Get a paged collection of authorized podcasts",
      profile: profile_url(:collection, :podcasts),
      href: api_authorization_podcasts_path + "{?page,per,zoom,since}",
      templated: true,
      count: represented.token_auth_podcasts.count
    }
  end

  link :podcast do
    {
      title: "Get a single authorized podcast",
      profile: profile_url(:podcast),
      href: api_authorization_podcast_path_template(id: "{id}") + "{?zoom}",
      templated: true
    }
  end

  def self_url(_r)
    api_authorization_path
  end
end
