module PodcastsHelper
  def full_contact(type, item)
    name = item.try("#{type}_name")
    email = item.try("#{type}_email")
    result = nil
    if !email.blank?
      result = email
      result = "#{result} (#{name})" if !name.blank?
    end
    result
  end

  def first_nonblank(type, items)
    items.find { |item| !item.send("#{type}").blank? }
  end
end
