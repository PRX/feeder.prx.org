class EpisodePolicy < ApplicationPolicy
  def create?
    update?
  end

  def update?
    token&.authorized?(account_id, :episode) ||
      ( token&.authorized?(account_id, :episode_draft) && resource.draft? && resource.was_draft? )
  end

  def destroy?
    token && token.authorized?(account_id, :admin)
  end

  def account_id
    resource.podcast.account_id
  end
end
