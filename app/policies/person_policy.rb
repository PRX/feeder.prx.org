class PersonPolicy < ApplicationPolicy
  def show?
    owner_policy.show?
  end

  def create?
    update?
  end

  def update?
    owner_policy.update?
  end

  def destroy?
    update?
  end

  private

  def owner_policy
    if resource.owner.is_a?(Podcast)
      PodcastPolicy.new(token, resource.owner)
    else
      EpisodePolicy.new(token, resource.owner)
    end
  end
end
