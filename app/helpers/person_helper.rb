require "text_sanitizer"

module PersonHelper
  def person_role_options
    Person.roles.keys.map { |val| [I18n.t("helpers.label.person.roles.#{val}"), val] }
  end

  def person_class(person, field)
    if person.errors[field].present? && person.changes[field].present?
      "is-changed is-invalid"
    elsif person.errors[field].present?
      "is-invalid"
    elsif person.changes[field].present?
      "is-changed"
    end
  end
end
