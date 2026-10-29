# Faraday's logger middleware logs request URLs and headers, so filter them
# with the app's filter_parameters in every `builder.response :logger`.
class FilteredFaradayFormatter < Faraday::Logging::Formatter
  def request(env)
    super(env.merge(url: filter_url(env.url)))
  end

  private

  def dump_headers(headers)
    super(headers.to_h { |key, value| [key, filter_param(key.tr("-", "_"), value)] })
  end

  def filter_url(url)
    return url if url.query.blank?

    url.dup.tap do |filtered|
      filtered.query = URI.encode_www_form(URI.decode_www_form(url.query).map { |key, value| [key, filter_param(key, value)] })
    end
  end

  def filter_param(key, value)
    @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    @parameter_filter.filter_param(key, value)
  end
end

Faraday::Response::Logger.default_options = {formatter: FilteredFaradayFormatter}
