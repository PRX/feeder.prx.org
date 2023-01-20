# frozen_string_literal: true

class CreateAppleCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_credentials do |t|
      t.references :public_feed, index: true
      t.references :private_feed, index: true
      t.string :apple_provider_id
      t.string :apple_key_id
      t.text :apple_key_pem_b64
      t.timestamps
    end

    add_foreign_key :apple_credentials, :feeds, column: :public_feed_id
    add_foreign_key :apple_credentials, :feeds, column: :private_feed_id
  end
end
