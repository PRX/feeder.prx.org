class PodcastPolicy < ApplicationPolicy
  def create?
    authorized?(:podcast_create)
  end

  def update?
    authorized?(:podcast_edit)
  end

  def destroy?
    authorized?(:podcast_delete)
  end

  private

  def account_id
    resource.account_id
  end

  def account_id_was
    resource.account_id_was
  end
end
