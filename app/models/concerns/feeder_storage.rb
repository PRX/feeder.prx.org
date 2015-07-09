require 'active_support/concern'

module FeederStorage
  extend ActiveSupport::Concern

  def feeder_storage_bucket
    ENV['FEEDER_STORAGE_BUCKET'] ||
      (Rails.env.production? ? '' : (Rails.env + '-')) + 'prx-feed'
  end
end
