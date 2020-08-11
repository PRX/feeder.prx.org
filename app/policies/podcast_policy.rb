class PodcastPolicy < ApplicationPolicy
  def create?
    token&.authorized?(account_id, :podcast_create)
  end

  def update?
    token&.authorized?(account_id, :podcast_edit)
  end

  def destroy?
    token&.authorized?(account_id, :podcast_delete)
  end

  def account_id
    resource.account_id
  end
end
