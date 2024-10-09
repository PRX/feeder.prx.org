module Megaphone
  class Config < ApplicationRecord
    belongs_to :feed

    validates_presence_of :token, :network_id, :feed_id

    encrypts :token
    encrypts :network_id
  end
end
