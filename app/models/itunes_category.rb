class ITunesCategory < BaseModel
  belongs_to :podcast, touch: true
  serialize :subcategories, JSON

  validates_with ITunesCategoryValidator
end
