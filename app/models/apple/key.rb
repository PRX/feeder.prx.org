# frozen_string_literal: true

module Apple
  class Key < ApplicationRecord
    validates :provider_id, presence: true, length: {minimum: 10}
    validates :key_id, presence: true, length: {minimum: 10}
    validates_presence_of :key_pem_b64

    validate :provider_id_is_valid, if: :provider_id?
    validate :correct_key_pem_format, if: :key_pem_b64?

    def provider_id_is_valid
      if provider_id.include?("_")
        errors.add(:provider_id, "cannot contain an underscore")
      end
    end

    def key_pem
      Base64.decode64(key_pem_b64)
    end

    def correct_key_pem_format
      header = "-----BEGIN"
      footer = "-----END"
      lines = key_pem.split("\n")
      unless lines[0].include?(header) && lines[-1].include?(footer)
        errors.add(:key_pem, "key pem does not have correct header or footer")
      end
    end
  end
end
