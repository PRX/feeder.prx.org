class ExtractCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_keys do |t|
      t.string :provider_id
      t.string :key_id
      t.text :key_pem_b64
      t.timestamps
    end

    add_reference :apple_configs, :key, index: true

    reversible do |direction|
      direction.up do
        Apple::Config.distinct.pluck(:apple_provider_id, :apple_key_id, :apple_key_pem_b64).each do |(apple_provider_id, apple_key_id, apple_key_pem_b64)|
          cred = Apple::Key.create!(
            provider_id: apple_provider_id,
            key_id: apple_key_id,
            key_pem_b64: apple_key_pem_b64
          )

          Apple::Config.where(apple_provider_id: apple_provider_id, apple_key_id: apple_key_id, apple_key_pem_b64: apple_key_pem_b64).each do |config|
            config.update!(key_id: cred.id)
          end
        end
      end

      direction.down do
        Apple::Config.all.each do |config|
          config.update!(
            apple_key_id: config.key.key_id,
            apple_provider_id: config.key.provider_id,
            apple_key_pem_b64: config.key.key_pem_b64
          )
        end
      end
    end

    remove_column :apple_configs, :apple_provider_id, :text
    remove_column :apple_configs, :apple_key_id, :text
    remove_column :apple_configs, :apple_key_pem_b64, :text
  end
end
