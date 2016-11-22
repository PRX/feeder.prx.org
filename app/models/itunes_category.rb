class ITunesCategory < BaseModel
  belongs_to :podcast
  serialize :subcategories, JSON

  validates_with ITunesCategoryValidator
end
