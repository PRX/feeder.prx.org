require 'fastimage'

class ItunesImageValidator < ActiveModel::Validator
  def validate(record)
    if record.url
      validate_size(record)
      validate_type(record)
    else
      record.errors[:url] = "can't be blank"
    end
  end

  private

  def validate_size(record)
    height, width = FastImage.size(record.url)

    check_too_small(record, height, width)
    check_proportions(record, height, width)
    check_too_large(record, height, width)
  end

  def check_too_large(record, height, width)
    if height > 2048 || width > 2048
      record.errors[:size] = "Image is too large"
    end
  end

  def check_too_small(record, height, width)
    if height < 1400 || width < 1400
      record.errors[:size] = "Image is too small"
    end
  end

  def check_proportions(record, height, width)
    if height != width
      record.errors[:size] = "Image must be square"
    end
  end

  def validate_type(record)
    unless [:jpg, :jpeg, :png].include? FastImage.type(record.url)
      record.errors[:type] = "Image must be a JPG or PNG"
    end
  end
end
