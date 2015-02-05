require 'fastimage'

class FeedImageValidator < ActiveModel::Validator
  def validate(record)
    if record.url
      validate_size(record)
      validate_type(record)
    else
      record.errors[:url] = "can't be blank"
    end

    record.errors[:link] = "can't be blank" unless record.link
    record.errors[:title] = "can't be blank" unless record.title
  end

  private

  def validate_size(record)
    dimensions = FastImage.size(record.url)

    if dimensions.any? { |d| d > 2048 }
      record.errors[:size] = "Image is too large"
    end
  end

  def validate_type(record)
    type = FastImage.type(record.url)

    unless [:jpg, :png, :gif].include?(type)
      record.errors[:type] = "Image must be a jpg, gif, or png"
    end
  end
end
