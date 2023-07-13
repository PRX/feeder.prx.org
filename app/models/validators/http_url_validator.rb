class HttpUrlValidator < ActiveModel::EachValidator
  def self.http_url?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    false
  end

  def validate_each(record, attribute, value)
    if value.present? && !self.class.http_url?(value)
      record.errors.add(attribute, :not_http_url)
    end
  end
end
