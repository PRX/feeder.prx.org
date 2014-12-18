class ItunesCategory < ActiveRecord::Base
  belongs_to :podcast

  validates_with ItunesCategoryValidator
end
