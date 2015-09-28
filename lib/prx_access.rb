module PRXAccess
  def api(options = {})
    opts = { root: cms_root }.merge(options)
    if account = opts.delete(:account)
      token = get_account_token(account)
      opts[:headers] = { 'Authorization' =>  "Bearer #{token}" }
    end

    HyperResource.new(opts)
  end

  def api_resource(body, root = cms_root)
    href = body['_links']['self']['href']
    resource = api(root: root)
    link = HyperResource::Link.new(resource, href: href)
    # puts "href: #{href}"
    # puts "resource: #{resource.inspect}"
    # puts "link: #{link.inspect}"
    HyperResource.new_from(body: body, resource: resource, link: link)
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
    ENV['ID_ROOT']
  end

  def cms_root
    ENV['CMS_ROOT']
  end

  def prx_root
    ENV['PRX_ROOT']
  end

  def crier_root
    ENV['CRIER_ROOT']
  end
end
