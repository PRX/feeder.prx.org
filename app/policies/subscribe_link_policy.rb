class SubscribeLinkPolicy < ApplicationPolicy
  def create?
    update?
  end

  def update?
    PodcastPolicy.new(token, resource.podcast).update?
  end

  def destroy?
    update?
  end
end
