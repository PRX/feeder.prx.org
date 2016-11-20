class AddPRXAccountId < ActiveRecord::Migration
  def change
    add_column :podcasts, :prx_account_uri, :string
  end
end
