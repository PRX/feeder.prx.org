Rails.application.config.dartsass.build_options.push(
  "--quiet-deps",
  # temporary - we should probably fix these
  "--silence-deprecation=global-builtin",
  "--silence-deprecation=import",
  "--silence-deprecation=mixed-decls"
)
