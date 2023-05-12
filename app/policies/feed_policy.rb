class FeedPolicy < ApplicationPolicy
  def show?
    PodcastPolicy.new(token, resource.podcast).show?
  end

  def create?
    PodcastPolicy.new(token, resource.podcast).create?
  end

  def update?
    PodcastPolicy.new(token, resource.podcast).update?
  end

  def destroy?
    PodcastPolicy.new(token, resource.podcast).destroy?
  end

  def account_id
    resource.podcast.account_id
  end
end
