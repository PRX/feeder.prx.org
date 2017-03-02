module PodcastsHelper
  def episode_contact(type, ep)
    name = ep.try("#{type}_name")
    email = ep.try("#{type}_email")
    result = nil
    if !email.blank?
      result = email
      result = "#{result} (#{name})" if !name.blank?
    end
    result
  end
end
