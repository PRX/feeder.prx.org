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
    update?
  end

  def update?
    PodcastPolicy.new(token, resource.podcast).update? && !resource.edit_locked?
  end

  def destroy?
    resource.custom? && update? && !resource.apple?
  end
end
