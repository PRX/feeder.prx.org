# encoding: utf-8

class Api::ApiRepresenter < Api::BaseRepresenter
  property :version

  def self_url(represented)
    api_root_path(represented.version)
  end

  links :episode do
    [
      {
        title:     "Get a single episode",
        profile:   profile_url(:episode),
        href:      api_episode_path_template(api_version: represented.version, id: '{id}') + '{?zoom}',
        templated: true
      }
    ]
  end

  links :episodes do
    [
      {
        title:     "Get a paged collection of episodes",
        profile:   profile_url(:collection, :episode),
        href:      api_episodes_path_template(api_version: represented.version) + '{?page,per,zoom,since}',
        templated: true
      }
    ]
  end

  links :podcast do
    [
      {
        title:     "Get a single podcast",
        profile:   profile_url(:podcast),
        href:      api_podcast_path_template(api_version: represented.version, id: '{id}') + '{?zoom}',
        templated: true
      }
    ]
  end

  links :podcasts do
    [
      {
        title:     "Get a paged collection of podcasts",
        profile:   profile_url(:collection, :podcasts),
        href:      api_podcasts_path_template(api_version: represented.version) + '{?page,per,zoom,since}',
        templated: true
      }
    ]
  end

  link :authorization do
    {
      title: 'Get information about the active authorization for this request',
      profile: 'http://meta.prx.org/model/user',
      href: api_authorization_path,
      templated: false
    }
  end
end
