# frozen_string_literal: true

module Apple
  class Key < ApplicationRecord
    validates :provider_id, presence: true, length: {minimum: 10}
    validates :key_id, presence: true, length: {minimum: 10}
    validates_presence_of :key_pem_b64

    validate :provider_id_is_valid, if: :provider_id?
    validate :ec_key_format, if: :key_pem_b64?
    validate :must_have_working_key

    def must_have_working_key
      return if Rails.env.test? || !changed?
      api = Apple::Api.from_key(self)
      Apple::Show.apple_shows_json(api)
    rescue => err
      logger.error(err)
      errors.add(:key_id, "must have a working Apple key")
    end

    def provider_id_is_valid
      if provider_id.include?("_")
        errors.add(:provider_id, "cannot contain an underscore")
      end
    end

    def key_pem
      Base64.decode64(key_pem_b64)
    end

    def ec_key_format
      unless passes_openssl_validation?
        errors.add(:key_pem, "ec key format did not pass OpenSSL validation")
      end
    end

    def passes_openssl_validation?
      OpenSSL::PKey::EC.new(key_pem)
      true
    rescue
      false
    end
  end
end
