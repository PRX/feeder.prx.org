module CurrentUserHelper
  def current_user_app?(name)
    current_user && current_user_app(name).present?
  end

  def current_user_app(name)
    current_user_apps.values.find do |url|
      url.include?("#{name}.prx.org") || url.include?("#{name}.staging.prx.tech")
    end
  end

  def current_user_id_profile
    "//#{PrxAuth::Rails.configuration.id_host}/profile"
  end

  def current_user_image?
    current_user && current_user_image.present?
  end

  def current_user_image
    current_user_info["image_href"]
  end
end
