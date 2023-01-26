class FeedPolicy < ApplicationPolicy
  def create?
    token&.authorized?(account_id)
  end

  def update?
    token&.authorized?(account_id)
  end

  def destroy?
    token&.authorized?(account_id, :admin)
  end

  def account_id
    resource.podcast.account_id
  end
end
