module LocationHelper
  def location_rel_options
    Location.rels.keys.map { |val| [I18n.t("helpers.label.location.rels.#{val}"), val] }
  end

  def location_search_url(owner)
    language = owner.is_a?(Episode) ? owner.podcast&.language : owner.try(:language)
    location_search_path(language: language.presence)
  end
end
