# encoding: utf-8
require 'hal_api/representer'
require 'prx_access'

class Api::BaseRepresenter < HalApi::Representer
  include PRXAccess
  self.alternate_host = ENV['PRX_HOST'] || 'www.prx.org'
  self.profile_host = ENV['META_HOST'] || 'meta.prx.org'

  curies(:prx) do
    [{
      name: :prx,
      href: "http://#{profile_host}/relation/{rel}",
      templated: true
    }]
  end
end
