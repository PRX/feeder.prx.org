class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include HalApi::RepresentedModel

  def self.alias_error_messages(to_field, from_field)
    aliases = error_message_aliases
    aliases[to_field.to_s] = from_field.to_s
    class_variable_set(:@@error_message_aliases, aliases)
  end

  def self.error_message_aliases
    if class_variable_defined?(:@@error_message_aliases)
      class_variable_get(:@@error_message_aliases)
    else
      {}
    end
  end

  def error_message_aliases
    self.class.error_message_aliases
  end

  def locking_enabled?
    !!(super && @locking_enabled)
  end

  attr_writer :locking_enabled

  def stale?
    !!try(:lock_version_changed?)
  end
end
