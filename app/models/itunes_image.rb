class ItunesImage < ActiveRecord::Base
  belongs_to :podcast

  validates_with ItunesImageValidator
end
