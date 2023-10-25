require "active_support/concern"

module FeedITunesCategory
  extend ActiveSupport::Concern

  included do
    alias_error_messages :itunes_category, :"itunes_categories.name"
  end

  def itunes_category
    itunes_categories.reject(&:marked_for_destruction?).map(&:name).compact
  end

  def itunes_category=(val)
    names = Array(val).reject(&:blank?)

    # add new categories
    names.each do |name|
      itunes_categories.build(name: name) unless itunes_categories.map(&:name).include?(name)
    end

    # remove gone categories
    itunes_categories.each do |cat|
      cat.mark_for_destruction unless names.include?(cat.name)
    end

    # default feeds must have at least one category - add a blank one to trigger validaiton errors
    if default? && itunes_categories.all?(&:marked_for_destruction?)
      itunes_categories.build(name: nil)
    end
  end

  def itunes_subcategory
    itunes_categories.reject(&:marked_for_destruction?).map(&:subcategories).flatten.compact.uniq.sort
  end

  def itunes_subcategory=(val)
    names = Array(val).reject(&:blank?)

    itunes_categories.each do |cat|
      cat.subcategories = names & (ITunesCategoryValidator::CATEGORIES[cat.name] || [])
    end
  end

  def itunes_category_options
    ((itunes_category || []) + ITunesCategoryValidator::CATEGORIES.keys).uniq
  end

  def itunes_category_map
    ITunesCategoryValidator::CATEGORIES
  end

  def itunes_subcategory_options
    (itunes_category || []).map { |c| ITunesCategoryValidator::CATEGORIES[c] || [] }.flatten
  end
end
