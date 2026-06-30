class AddEncryptionToKeyPemB64 < ActiveRecord::Migration[7.2]
  def up
    Apple::Key.reset_column_information
    encrypted_type = Apple::Key.type_for_attribute("key_pem_b64")

    connection.select_all(<<~SQL.squish).each do |row|
      SELECT id, key_pem_b64
      FROM apple_keys
      WHERE key_pem_b64 IS NOT NULL
    SQL
      raw_key_pem_b64 = row.fetch("key_pem_b64")
      next if encrypted_type.encrypted?(raw_key_pem_b64)

      Apple::Key.where(id: row.fetch("id")).update_all(
        key_pem_b64: raw_key_pem_b64,
        updated_at: Time.current
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Apple key PEM values cannot be decrypted safely by this migration"
  end
end
