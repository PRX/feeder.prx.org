class ChangeAppleCredentialsToAppleConfigs < ActiveRecord::Migration[7.0]
  def change
    rename_table :apple_credentials, :apple_configs
  end
end
