class FeedPolicy < ApplicationPolicy
  def show?
    PodcastPolicy.new(token, resource.podcast).show?
  end

  def create?
    update?
  end

  def update?
    PodcastPolicy.new(token, resource.podcast).update?
  end

  def destroy?
    update?
  end

  def account_id
    resource.podcast.account_id
  end
end
