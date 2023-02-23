class AddEnabledColumnToAppleCredentials < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_credentials, :publish_enabled, :boolean, default: false, null: false
  end
end
