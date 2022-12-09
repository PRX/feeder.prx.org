class ITunesCategory < ApplicationRecord
  belongs_to :podcast, touch: true, optional: true
  serialize :subcategories, JSON

  validates_with ITunesCategoryValidator
end
