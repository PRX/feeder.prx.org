# encoding: utf-8

class BaseModel < ActiveRecord::Base
  self.abstract_class = true
  include HalApi::RepresentedModel
end
