class TruncateSessions < ActiveRecord::Migration[7.0]
  def change
    execute("TRUNCATE TABLE sessions;")
  end
end
