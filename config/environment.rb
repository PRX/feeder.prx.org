require "opentelemetry/sdk"

# Load the Rails application.
require_relative "application"

if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present? && !Rails.const_defined?(:Console)
  OpenTelemetry::SDK.configure do |c|
    c.use_all
  end
end

# Initialize the Rails application.
Rails.application.initialize!
