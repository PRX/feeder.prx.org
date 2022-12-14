# frozen_string_literal: true

class AppleCredential < BaseModel
  belongs_to :public_feed, class_name: "Feed"
  belongs_to :private_feed, class_name: "Feed"

  validates_presence_of :public_feed
  validates_presence_of :private_feed
  validates_associated :public_feed
  validates_associated :private_feed
  validates_presence_of :apple_provider_id, if: :any_apple_credentials_exist?
  validates_presence_of :apple_key_id, if: :any_apple_credentials_exist?
  validates_presence_of :apple_key_pem_b64, if: :any_apple_credentials_exist?
  validates :public_feed, uniqueness: { scope: :private_feed,
                                        message: "can only have one credential per public and private feed" }
  validates :public_feed, exclusion: { in: ->(apple_credential) { [apple_credential.private_feed] } }

  def any_apple_credentials_exist?
    apple_provider_id.present? || apple_key_id.present? || apple_key_pem_b64.present?
  end
end
