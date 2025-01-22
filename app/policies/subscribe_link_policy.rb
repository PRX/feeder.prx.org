class SubscribeLinkPolicy < ApplicationPolicy
  def create?
    update?
  end

  def update?
    true
  end

  def destroy?
    update?
  end
end
