# frozen_string_literal: true

module Apple
  class Config < ApplicationRecord
    belongs_to :public_feed, class_name: "Feed"
    belongs_to :private_feed, class_name: "Feed"

    belongs_to :key, class_name: "Apple::Key", optional: true

    has_one :podcast, through: :public_feed

    delegate :title, to: :podcast, prefix: "podcast"
    delegate :id, to: :podcast, prefix: "podcast"

    delegate :provider_id, to: :key
    delegate :key_id, to: :key
    delegate :key_pem, to: :key
    delegate :key_pem_b64, to: :key

    validates_presence_of :public_feed
    validates_presence_of :private_feed

    validates_associated :public_feed
    validates_associated :private_feed

    validates :public_feed, uniqueness: {scope: :private_feed,
                                         message: "can only have one credential per public and private feed"}
    validates :public_feed, exclusion: {in: ->(apple_credential) { [apple_credential.private_feed] }}

    def publish_to_apple?
      return false unless key&.valid?

      public_feed.publish_to_apple?(self)
    end

    def build_publisher
      Apple::Publisher.from_apple_config(self)
    end

    def apple_key
      Base64.decode64(apple_key_pem_b64)
    end
  end
end
