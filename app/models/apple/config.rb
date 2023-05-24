# frozen_string_literal: true

module Apple
  class Config < ApplicationRecord
    belongs_to :public_feed, class_name: "Feed"
    belongs_to :private_feed, class_name: "Feed"

    has_one :podcast, through: :public_feed

    delegate :title, to: :podcast, prefix: "podcast"
    delegate :id, to: :podcast, prefix: "podcast"

    validates_presence_of :public_feed
    validates_presence_of :private_feed

    validates_associated :public_feed
    validates_associated :private_feed
    validates_presence_of :apple_provider_id, if: :any_apple_credentials_exist?
    validates_presence_of :apple_key_id, if: :any_apple_credentials_exist?
    validates_presence_of :apple_key_pem_b64, if: :any_apple_credentials_exist?
    validates :public_feed, uniqueness: {scope: :private_feed,
                                         message: "can only have one credential per public and private feed"}
    validates :public_feed, exclusion: {in: ->(apple_credential) { [apple_credential.private_feed] }}

    validate :apple_provider_id_is_valid, if: :apple_provider_id?

    def apple_provider_id_is_valid
      # ensure that it does not have an underscore
      if apple_provider_id.include?("_")
        errors.add(:apple_provider_id, "cannot contain an underscore")
      end
    end

    def build_publisher
      Apple::Publisher.from_apple_config(self)
    end

    def any_apple_credentials_exist?
      apple_provider_id.present? || apple_key_id.present? || apple_key_pem_b64.present?
    end

    def no_apple_credentials?
      !any_apple_credentials_exist?
    end

    def apple_key
      Base64.decode64(apple_key_pem_b64)
    end
  end
end
