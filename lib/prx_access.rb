module PRXAccess

  class PRXHyperResource < HyperResource
    def incoming_body_filter(hash)
      super(hash.deep_transform_keys { |key| key.to_s.underscore })
    end

    class Link < HyperResource::Link
      attr_accessor :type, :profile

      def initialize(resource, link_spec={})
        super
        self.type = link_spec['type']
        self.profile = link_spec['profile']
      end

      def where(params)
        super.tap do |res|
          res.type = self.type
          res.profile = self.profile
        end
      end

      def headers(*args)
        super.tap do |res|
          if args.count > 0
            res.type = self.type
            res.profile = self.profile
          end
        end
      end
    end
  end

  def default_headers
    {
      'Content-Type' => 'application/json',
      'Accept' =>  'application/json'
    }
  end

  def api(options = {})
    opts = { root: cms_root, headers: default_headers }.merge(options)
    if account = opts.delete(:account)
      token = get_account_token(account)
      opts[:headers]['Authorization'] = "Bearer #{token}"
    end

    PRXHyperResource.new(opts)
  end

  def api_resource(body, root = cms_root)
    href = body['_links']['self']['href']
    resource = api(root: root)
    link = PRXHyperResource::Link.new(resource, href: href)
    PRXHyperResource.new_from(body: body, resource: resource, link: link)
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
    root_uri ENV['ID_HOST']
  end

  def cms_root
    root_uri ENV['CMS_HOST'], '/api/v1'
  end

  def crier_root
    root_uri ENV['CRIER_HOST'], '/api/v1'
  end

  def feeder_root
    root_uri ENV['FEEDER_HOST'], '/api/v1'
  end

  private

  def root_uri(host, path = '')
    if host =~ /\.org/ # TODO: should .tech's be here too?
      URI::HTTPS.build(host: host, path: path).to_s
    else
      URI::HTTP.build(host: host, path: path).to_s
    end
  end

end
