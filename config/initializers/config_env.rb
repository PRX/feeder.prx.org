# default env vars that may not be set
ENV['ID_ROOT'] ||= 'https://id.prx.org/'
ENV['CMS_ROOT'] ||= 'https://cms.prx.org/api/v1/'
ENV['PRX_ROOT'] ||= 'https://beta.prx.org/stories/'
ENV['CRIER_ROOT'] ||= 'https://crier.prx.org/api/v1'
ENV['FEEDER_WEB_MASTER'] ||= 'prxhelp@prx.org (PRX)'
ENV['FEEDER_GENERATOR'] ||= "PRX Feeder v#{Feeder::VERSION}"

env_prefix = Rails.env.production? ? '' : (Rails.env + '-')
ENV['FEEDER_CDN_HOST'] ||= "#{env_prefix}f.prxu.org"
ENV['FEEDER_STORAGE_BUCKET'] ||= "#{env_prefix}prx-feed"

env_suffix = Rails.env.development? ? 'dev' : 'org'
ENV['FEEDER_APP_HOST'] ||= "feeder.prx.#{env_suffix}"
