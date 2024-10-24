class Apple::ConfigPolicy < ApplicationPolicy
  def new?
    create?
  end

  def show?
    FeedPolicy.new(token, resource.feed).show?
  end

  def create?
    FeedPolicy.new(token, resource.feed).create?
  end

  def update?
    FeedPolicy.new(token, resource.feed).update?
  end
end
