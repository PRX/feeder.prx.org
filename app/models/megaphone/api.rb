module Megaphone
  class Api
    attr_accessor :token, :network_id, :endpoint_url

    DEFAULT_ENDPOINT = "https://cms.megaphone.fm/api"

    PAGINATION_HEADERS = %w[link x-per-page x-page x-total]
    PAGINATION_LINKS = %w[first last next previous]

    def initialize(token:, network_id:, endpoint_url: nil)
      @token = token
      @network_id = network_id
      @endpoint_url = endpoint_url
    end

    def get(path, params = {}, headers = {})
      request = {url: join_url(path), headers: headers, params: params}
      response = get_url(request)
      data = incoming_body_filter(response.body)
      if data.is_a?(Array)
        pagination = pagination_from_headers(response.env.response_headers)
        {items: data, pagination: pagination, request: request, response: response}
      else
        {items: [data], pagination: {}, request: request, response: response}
      end
    end

    def post(path, body, headers = {})
      response = connection({url: join_url(path), headers: headers}).post do |req|
        req.body = outgoing_body_filter(body)
      end
      incoming_body_filter(response.body)
    end

    def put(path, body, headers = {})
      connection({url: join_url(path), headers: headers}).put do |req|
        req.body = outgoing_body_filter(body)
      end
      incoming_body_filter(response.body)
    end

    # TODO: and we need delete...

    def api_base
      @endpoint_url || DEFAULT_ENDPOINT
    end

    def pagination_from_headers(headers)
      paging = (headers || {}).slice(*PAGINATION_HEADERS).transform_keys do |h|
        h.sub(/^x-/, "").tr("-", "_").to_sym
      end

      [:page, :per_page, :total].each do |k|
        paging[k] = paging[k].to_i if paging.key?(k)
      end

      paging[:link] = parse_links(paging[:link])

      paging
    end

    def parse_links(link_headers)
      return {} unless link_headers.present?
      collection = LinkHeaderParser.parse(link_headers, base: mp.api.api_base)
      links = collection.group_by_relation_type
      PAGINATION_LINKS.each_with_object({}) do |key, map|
        if (link = (links[key] || []).first)
          map[key] = link.target_uri
        end
      end
    end

    def get_url(options)
      connection(options).get
    end

    def join_url(*path)
      File.join(api_base, "networks", network_id, *path)
    end

    def incoming_body_filter(str)
      result = JSON.parse(str || "")
      transform_keys(result)
    end

    def transform_keys(result)
      if result.is_a?(Array)
        result.map { |r| transform_keys(r) }
      elsif result.respond_to?(:deep_transform_keys)
        result.deep_transform_keys { |key| key.to_s.underscore.to_sym }
      else
        result
      end
    end

    def outgoing_body_filter(attr)
      (attr || {}).deep_transform_keys { |key| key.to_s.camelize(:lower) }.to_json
    end

    def default_headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => "PRX-Feeder-Megaphone/1.0 (Rails-#{Rails.env})"
      }
    end

    def connection(options)
      url = options[:url]
      headers = default_headers.merge(options[:headers] || {})
      params = options[:params] || {}
      Faraday.new(url: url, headers: headers, params: params) do |builder|
        builder.request :token_auth, token
        builder.response :raise_error
        builder.response :logger
        builder.adapter :excon
      end
    end
  end
end
