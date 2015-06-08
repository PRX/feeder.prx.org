class ITunesCategory < ActiveRecord::Base
  belongs_to :podcast

  validates_with ITunesCategoryValidator
end
