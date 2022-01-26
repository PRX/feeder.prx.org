class MediaRestrictionsValidator < ActiveModel::EachValidator
  # https://www.rssboard.org/media-rss/#media-restriction
  def validate_each(record, attribute, values)
    return if values.nil?

    # must have format [{type: '', relationship: '', values: []}]
    unless values.is_a?(Array)
      return record.errors.add attribute, 'has invalid restrictions'
    end
    values = values.try(:map) { |v| v.try(:with_indifferent_access) }
    unless values.all? { |v| valid_restriction?(v) }
      return record.errors.add attribute, 'has invalid restrictions'
    end

    # must have unique types
    types = values.map { |r| r[:type] }
    if types.detect { |t| types.count(t) > 1 }
      return record.errors.add attribute, 'has duplicate restriction types'
    end

    # per-type validations
    values.each do |value|
      if value[:type] == 'country'
        validate_country_codes(record, attribute, value)
      else
        record.errors.add attribute, 'has an unsupported restriction type'
      end
    end
  end

  private

  def valid_restriction?(value)
    value.is_a?(Hash) && %i(type relationship values).all? { |k| value.key?(k) }
  end

  # NOTE: Spotify only accepts allow+country ... so validate that for now
  def validate_country_codes(record, attribute, value)
    unless value[:relationship] == 'allow'
      return record.errors.add attribute, 'has an unsupported media restriction relationship'
    end

    if !value[:values].is_a?(Array) || value[:values].blank?
      record.errors.add attribute, 'does not have country code values'
    elsif !value[:values].all? { |v| ISO3166::Country[v] }
      record.errors.add attribute, 'has non-ISO3166 country codes'
    end
  end
end
