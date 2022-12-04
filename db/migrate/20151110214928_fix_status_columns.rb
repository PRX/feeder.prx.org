class FixStatusColumns < ActiveRecord::Migration[4.2]
  def change
    remove_column :media_resources, :status, :string
    add_column :media_resources, :status, :integer
  end
end
