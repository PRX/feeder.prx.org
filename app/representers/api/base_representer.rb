# encoding: utf-8
require 'hal_api/representer'

class Api::BaseRepresenter < HalApi::Representer
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
