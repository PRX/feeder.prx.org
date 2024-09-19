class TranscriptPolicy < ApplicationPolicy
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
end
