class PlacementZonesValidator < ActiveModel::EachValidator
  ZONE_TYPES = %w(o a b i)

  def validate_each(record, attribute, value)
    return if value.nil?

    unless value.is_a?(Array)
      return record.errors.add attribute, 'has invalid zones'
    end

    # TODO: do we care about anything but zone types?
    unless value.all? { |s| ZONE_TYPES.include?(s) }
      return record.errors.add attribute, 'has invalid zone types'
    end
  end
end
