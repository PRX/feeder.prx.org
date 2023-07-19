# frozen_string_literal: true

module Apple
  class Key < ApplicationRecord
    validates_presence_of :provider_id
    validates_presence_of :key_id
    validates_presence_of :key_pem_b64

    validate :provider_id_is_valid, if: :provider_id?

    def provider_id_is_valid
      if provider_id.include?("_")
        errors.add(:provider_id, "cannot contain an underscore")
      end
    end

    def key_pem
      Base64.decode64(key_pem_b64)
    end
  end
end
