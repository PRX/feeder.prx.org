module Megaphone
  class Config < ApplicationRecord
    belongs_to :feed

    validates_presence_of :token, :network_id

    encrypts :token
    encrypts :network_id

    def publish_to_megaphone?
      valid? && publish_enabled?
    end
  end
end
