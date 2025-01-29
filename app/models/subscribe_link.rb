class SubscribeLink < ApplicationRecord
  TYPE_ABBREVIATIONS = {
    "SubscribeLinks::Apple" => "apple",
    "SubscribeLinks::Spotify" => "spotify"
  }

  belongs_to :podcast, -> { with_deleted }, optional: true, touch: true
  enum :type, TYPE_ABBREVIATIONS, prefix: true

  validate :only_one_of_each_link_type

  def only_one_of_each_link_type
    TYPE_ABBREVIATIONS.keys.each do |t|
      existing_link = t.constantize.where(podcast_id: podcast_id).where.not(id: id)
      if existing_link.any?
        errors.add(:subscribe_link, "cannot have more than one #{TYPE_ABBREVIATIONS[t]} link")
      end
    end
  end

  def label
    TYPE_ABBREVIATIONS[type]
  end
end
