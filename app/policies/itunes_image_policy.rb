class ITunesImagePolicy < ApplicationPolicy
  def create?
    update?
  end

  def update?
    if resource.podcast.present?
      FeedPolicy.new(token, resource.feed).update?
    else
      false
    end
  end

  def destroy?
    update?
  end
end
