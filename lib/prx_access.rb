module PRXAccess

  class PRXHyperResource < HyperResource
    def incoming_body_filter(hash)
      super(hash.deep_transform_keys { |key| key.to_s.underscore })
    end

    def outgoing_body_filter(hash)
      super(hash.deep_transform_keys { |key| key.to_s.camelize(:lower) })
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

      def post_response(attrs=nil)
        attrs ||= self.resource.attributes
        attrs = (self.resource.default_attributes || {}).merge(attrs)

        # adding this line to call outgoing_body_filter
        attrs = resource.outgoing_body_filter(attrs)

        response = faraday_connection.post do |req|
          req.body = self.resource.adapter.serialize(attrs)
        end
        response
      end

      def put_response(attrs=nil)
        attrs ||= self.resource.attributes
        attrs = (self.resource.default_attributes || {}).merge(attrs)

        # adding this line to call outgoing_body_filter
        attrs = resource.outgoing_body_filter(attrs)

        response = faraday_connection.put do |req|
          req.body = self.resource.adapter.serialize(attrs)
        end
        response
      end

      def patch_response(attrs=nil)
        attrs ||= self.resource.attributes.changed_attributes
        attrs = (self.resource.default_attributes || {}).merge(attrs)

        # adding this line to call outgoing_body_filter
        attrs = resource.outgoing_body_filter(attrs)

        response = faraday_connection.patch do |req|
          req.body = self.resource.adapter.serialize(attrs)
        end
        response
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
      faraday.adapter  :excon
    end
    client.client_credentials.get_token(account: account).token
  end

  def id_root
    root_uri ENV['ID_HOST']
  end

  private

  def method_missing(method, *args)
    if method =~ /_root$/
      root_uri ENV[method.to_s.sub(/_root$/, '_HOST').upcase], '/api/v1'
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    method.to_s.ends_with?('_root') || super
  end

  def root_uri(host, path = '')
    if host =~ /\.org|\.tech/
      URI::HTTPS.build(host: host, path: path).to_s
    else
      URI::HTTP.build(host: host, path: path).to_s
    end
  end
end
