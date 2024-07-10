class ITunesCategory < ApplicationRecord
  belongs_to :feed, touch: true, optional: true
  serialize :subcategories, coder: JSON

  validates_presence_of :name
  validates_with ITunesCategoryValidator

  def subcategories=(subcats)
    super subcats.select(&:present?)
  end
end
