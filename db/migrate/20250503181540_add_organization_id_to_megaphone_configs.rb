class AddOrganizationIdToMegaphoneConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :megaphone_configs, :organization_id, :string
  end
end
