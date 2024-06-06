class FeedPolicy < ApplicationPolicy
  def new?
    create?
  end

  def show?
    PodcastPolicy.new(token, resource.podcast).show?
  end

  def create?
    update?
  end

  def new_apple?
    create?
  end

  def update?
    PodcastPolicy.new(token, resource.podcast).update?
  end

  def destroy?
    resource.custom? && update? && resource.type != "Feeds::AppleSubscription"
  end
end
