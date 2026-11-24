require "text_sanitizer"

module PersonHelper
  def person_role_options
    Person.roles.keys.map { |val| [I18n.t("helpers.label.person.roles.#{val}"), val] }
  end
end
