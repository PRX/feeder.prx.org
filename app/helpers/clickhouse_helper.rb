module ClickhouseHelper
  def clickhouse_connected?
    ClickhouseUtils.clickhouse_connected?
  end
end
