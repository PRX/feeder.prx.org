class EpisodePolicy < ApplicationPolicy
  def create?
    token.present?
  end

  def update?
    token && token.authorized?(account_id)
  end

  def destroy?
    token && token.authorized?(account_id, :admin)
  end

  def account_id
    resource.podcast.account_id
  end
end
