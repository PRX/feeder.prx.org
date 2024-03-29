class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include HalApi::RepresentedModel

  @@error_message_aliases = {}

  def self.alias_error_messages(to_field, from_field)
    @@error_message_aliases[to_field.to_s] = from_field.to_s
  end

  def error_message_aliases
    @@error_message_aliases
  end
end
