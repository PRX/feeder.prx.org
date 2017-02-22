module PodcastsHelper
  def episode_contact(type, ep)
    name = ep.try("#{type}_name")
    email = ep.try("#{type}_email")
    result = nil
    unless email.blank?
      result = email
      result = "#{result} (#{name})" unless name.blank?
    end
    result
  end
end
