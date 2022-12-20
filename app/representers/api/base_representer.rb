# encoding: utf-8
require 'api'
require 'hal_api/representer'
require 'prx_access'
require 'text_sanitizer'

class Api::BaseRepresenter < HalApi::Representer
  include PrxAccess
  include TextSanitizer

  self.alternate_host = ENV['PRX_HOST'] || 'www.prx.org'
  self.profile_host = ENV['META_HOST'] || 'meta.prx.org'

  curies(:prx) do
    [{
      name: :prx,
      href: "http://#{profile_host}/relation/{rel}",
      templated: true
    }]
  end

  def summary_preview
    sanitize_links_only(represented.description)
  end
end
