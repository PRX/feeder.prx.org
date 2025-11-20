class StreamPolicy < ApplicationPolicy
  def show?
    PodcastPolicy.new(token, resource.podcast).show?
  end

  def create?
    update?
  end

  def update?
    PodcastPolicy.new(token, resource.podcast).update?
  end
end
