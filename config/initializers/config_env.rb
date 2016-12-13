# default env vars that may not be set
ENV['CMS_HOST']    ||= 'cms.prx.org'
ENV['CRIER_HOST']  ||= 'crier.prx.org'
ENV['FEEDER_HOST'] ||= 'feeder.prx.org'
ENV['ID_HOST']     ||= 'id.prx.org'
ENV['META_HOST']   ||= 'meta.prx.org'
ENV['PRX_HOST']    ||= 'www.prx.org'

# default env vars that may not be set
ENV['FEEDER_WEB_MASTER'] ||= 'prxhelp@prx.org (PRX)'
ENV['FEEDER_GENERATOR'] ||= "PRX Feeder v#{Feeder::VERSION}"

env_prefix = Rails.env.production? ? '' : (Rails.env + '-')
ENV['FEEDER_CDN_HOST'] ||= "#{env_prefix}f.prxu.org"
ENV['FEEDER_STORAGE_BUCKET'] ||= "#{env_prefix}prx-feed"
