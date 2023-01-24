class TagListValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?

    unless value.is_a?(Array)
      return record.errors.add attribute, "has invalid tags"
    end

    if value.blank?
      return record.errors.add attribute, "cannot be empty"
    end

    unless value.all? { |s| s.is_a?(String) }
      record.errors.add attribute, "has non-string tags"
    end
  end
end
