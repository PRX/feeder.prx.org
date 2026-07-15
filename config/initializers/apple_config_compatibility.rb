# Preserve the transitional Apple::Config name without keeping the old model
# path, so Apple::DelegatedDeliveryConfig retains its file history.
Rails.application.config.to_prepare do
  Apple.send(:remove_const, :Config) if Apple.const_defined?(:Config, false)
  Apple.const_set(:Config, Apple::DelegatedDeliveryConfig)
end
