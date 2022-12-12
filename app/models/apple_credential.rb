# frozen_string_literal: true

class AppleCredential < ActiveRecord::Base
  belongs_to :public_feed, class_name: "Feed"
  belongs_to :private_feed, class_name: "Feed"

  validates_presence_of :public_feed
  validates_presence_of :private_feed
  validates_associated :public_feed
  validates_associated :private_feed
  validates_presence_of :apple_key_id
  validates_presence_of :apple_key_pem_b64
  validates :public_feed, uniqueness: { scope: :private_feed,
                                        message: "can only have one credential per public and private feed" }
  validates :public_feed, exclusion: { in: ->(apple_credential) { [apple_credential.private_feed] } }
end
