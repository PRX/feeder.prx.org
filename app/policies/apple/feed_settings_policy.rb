class Apple::FeedSettingsPolicy < ApplicationPolicy
  def show?
    FeedPolicy.new(token, resource.feed).show?
  end

  def create_or_update?
    FeedPolicy.new(token, resource.feed).create_or_update?
  end
end
