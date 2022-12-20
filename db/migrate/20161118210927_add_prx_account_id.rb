class AddPrxAccountId < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :prx_account_uri, :string
  end
end
