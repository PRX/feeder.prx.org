# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 8.0 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `8.0`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# Specifies whether `to_time` methods preserve the UTC offset of their receivers or preserves the timezone.
# If set to `:zone`, `to_time` methods will use the timezone of their receivers.
# If set to `:offset`, `to_time` methods will use the UTC offset.
# If `false`, `to_time` methods will convert to the local system UTC offset instead.
#++
# DEFERRED. Two direct call sites in Tasks::RecordStreamTask (parsing timestamps
# out of job id parts), but `to_time` is also reachable through Active Support
# internals and gem code, and this app is scheduling-heavy. To verify: confirm
# RecordStreamTask start/end parsing still lines up, then spot-check episode
# publish times and the podcast planner across a DST boundary.
# Rails.application.config.active_support.to_time_preserves_timezone = :zone

###
# When both `If-Modified-Since` and `If-None-Match` are provided by the client
# only consider `If-None-Match` as specified by RFC 7232 Section 6.
# If set to `false` both conditions need to be satisfied.
#++
# ADOPTED -- but set in config/application.rb, not here. The Action Dispatch
# railtie copies this into ActionDispatch::Http::Cache::Request before
# config/initializers/* is loaded, so assigning it in this file has no effect.
# Inert either way: no controller calls fresh_when / stale? / etag, so nothing
# consults Rails' freshness logic. Rack-level ETag handling is unaffected.
# Rails.application.config.action_dispatch.strict_freshness = true

###
# Set `Regexp.timeout` to `1`s by default to improve security over Regexp Denial-of-Service attacks.
#++
# DEFERRED. Process-wide, and this app runs regexes over third-party RSS it does
# not control -- which is both the reason it is worth having and the reason it
# could bite. A pathological or merely large feed that currently takes >1s in a
# regex starts raising Regexp::TimeoutError. To verify: run imports of the
# largest known feeds with this on before enabling in production.
# Regexp.timeout = 1
