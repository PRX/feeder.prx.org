class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include HalApi::RepresentedModel
end
