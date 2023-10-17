module CurrentUserHelper
  def current_user_app?(name)
    current_user && current_user_app(name).present?
  end

  def current_user_app(name)
    current_user_apps.filter_map do |key, url|
      # TODO: temporary, as we shuffle/solidify these keys
      if name == "augury"
        url if key.downcase.include?(name) || key.downcase.include?("inventory")
      elsif name == "feeder"
        url if key.downcase.include?(name) || key.downcase.include?("podcasts")
      elsif key.downcase.include?(name)
        url
      end
    end.first
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
