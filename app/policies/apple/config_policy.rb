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
    false
  end
end
