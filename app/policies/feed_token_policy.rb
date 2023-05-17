class FeedTokenPolicy < ApplicationPolicy
  def show?
    if resource.feed.present?
      FeedPolicy.new(token, resource.feed).show?
    else
      false
    end
  end

  def create?
    update?
  end

  def update?
    if resource.feed.present?
      FeedPolicy.new(token, resource.feed).update?
    else
      false
    end
  end

  def destroy?
    update?
  end
end
