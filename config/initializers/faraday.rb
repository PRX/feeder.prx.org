# Faraday's logger middleware logs request headers, so filter credentials
# out of every `builder.response :logger` in the app.
class FilteredFaradayFormatter < Faraday::Logging::Formatter
  def initialize(...)
    super
    filter(/(Authorization: )"[^"]*"/, '\1"[FILTERED]"')
  end
end

Faraday::Response::Logger.default_options = {formatter: FilteredFaradayFormatter}
