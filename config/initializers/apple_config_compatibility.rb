# Preserve the legacy Apple::Config name as an alias of
# Apple::DelegatedDeliveryConfig so callers written against either name keep working.
Rails.application.config.to_prepare do
  Apple.send(:remove_const, :Config) if Apple.const_defined?(:Config, false)
  Apple.const_set(:Config, Apple::DelegatedDeliveryConfig)
end
