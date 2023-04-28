class ITunesCategory < ApplicationRecord
  belongs_to :podcast, touch: true, optional: true
  serialize :subcategories, JSON

  validates_presence_of :name
  validates_with ITunesCategoryValidator

  def subcategories=(subcats)
    super subcats.select(&:present?)
  end
end
