class MediaRestrictionValidator < ActiveModel::EachValidator
  # https://www.rssboard.org/media-rss/#media-restriction
  def validate_each(record, attribute, value)
    return if value.nil?

    # must have format {type: '', relationship: '', values: []}
    value = value.try(:with_indifferent_access)
    unless %i(type relationship values).all? { |k| value.try(:key?, k) }
      return record.errors.add attribute, 'is not a valid media restriction'
    end

    # NOTE: Spotify only accepts allow+country ... so validate that for now
    unless value[:type] == 'country' && value[:relationship] == 'allow'
      return record.errors.add attribute, 'is not an allowed-country restriction'
    end

    # per-type validations
    if value[:type] == 'country'
      validate_country_codes(record, attribute, value[:values])
    end
  end

  private

  def validate_country_codes(record, attribute, values)
    if !values.is_a?(Array) || values.blank?
      record.errors.add attribute, 'does not have country code values'
    elsif !values.all? { |v| ISO3166::Country[v] }
      record.errors.add attribute, 'has non-ISO3166 country codes'
    end
  end
end
