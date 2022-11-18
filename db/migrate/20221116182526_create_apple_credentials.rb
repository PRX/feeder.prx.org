class CreateAppleCredentials < ActiveRecord::Migration
  def change
    create_table :apple_credentials do |t|
      t.references :podcast, index: true, foreign_key: true
      t.string :prx_account_uri

      t.string :apple_key_id
      t.text :apple_key_pem_b64

      t.timestamps
    end
  end
end
