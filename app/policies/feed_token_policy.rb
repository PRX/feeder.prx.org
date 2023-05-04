class FeedTokenPolicy < ApplicationPolicy
  def update?
    if resource.feed.present?
      FeedPolicy.new(token, resource.feed).update?
    else
      false
    end
  end
end
