module PrxAccess
  def api(account = nil)
    options = { root: cms_root }
    if account
      token = get_account_token(account)
      options[:headers] = { 'Authorization' =>  "Bearer #{token}" }
    end

    HyperResource.new(options)
  end

  def get_account_token(account)
    id = ENV['PRX_CLIENT_ID']
    se = ENV['PRX_SECRET']
    oauth_options = { site: id_root, token_url: '/token' }
    client = OAuth2::Client.new(id, se, oauth_options) do |faraday|
      faraday.request  :url_encoded
      faraday.response :logger
      faraday.adapter  :excon
    end
    client.client_credentials.get_token(account: account).token
  end

  def id_root
    ENV['ID_ROOT'] || 'https://id.prx.org/'
  end

  def cms_root
    ENV['CMS_ROOT'] || 'https://cms.prx.org/api/vi/'
  end

  def prx_root
    ENV['PRX_ROOT'] || 'https://beta.prx.org/stories/'
  end
end
