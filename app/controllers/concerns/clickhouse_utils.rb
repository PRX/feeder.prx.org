require "active_support/concern"

module ClickhouseUtils
  extend ActiveSupport::Concern

  CLICKHOUSE_PING_INTERVAL = 5.seconds
  CLICKHOUSE_PING_TIMEOUT = 0.5

  # clickhouse-activerecord has a slow timeout, so make our own check
  def self.clickhouse_connected?
    if clickhouse_config[:host].blank?
      false
    elsif Rollups::DailyGeo.connected?
      true
    elsif ActionController::Base.perform_caching
      Rails.cache.fetch("clickhouse_connected?", expires_in: CLICKHOUSE_PING_INTERVAL) do
        clickhouse_ping
      end
    elsif defined?(@@clickhouse_at) && (Time.now - @@clickhouse_at) < CLICKHOUSE_PING_INTERVAL
      @@clickhouse_connected
    else
      @@clickhouse_connected = clickhouse_ping
      @@clickhouse_at = Time.now
    end
  end

  def clickhouse_connected?
    self.class.clickhouse_connected?
  end

  def self.clickhouse_config
    Rollups::DailyAgent.connection_db_config.configuration_hash
  end

  def self.clickhouse_ping
    host = clickhouse_config[:host]
    port = clickhouse_config[:port]
    ssl = clickhouse_config[:ssl]
    ver = OpenSSL::SSL::VERIFY_NONE
    to = CLICKHOUSE_PING_TIMEOUT

    begin
      Net::HTTP.start(host, port, use_ssl: ssl, verify_mode: ver, connect_timeout: to, open_timeout: to)
      true
    rescue
      false
    end
  end
end
