class MediaResourcePolicy < ApplicationPolicy
  def create?
    update?
  end

  def update?
    if resource.episode.present?
      EpisodePolicy.new(token, resource.episode).update?
    else
      false
    end
  end

  def destroy?
    update?
  end

  def upload?
    %i[podcast_create podcast_edit podcast_delete episode episode_draft].any? do |scope|
      token.globally_authorized?(scope) || token.resources(scope).present?
    end
  end
end
