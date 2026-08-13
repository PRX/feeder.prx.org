class Apple::KeyPolicy < ApplicationPolicy
  def new?
    create?
  end

  def show?
    authorized?(:read_private)
  end

  def create?
    authorized?(:podcast_edit)
  end

  def update?
    authorized?(:podcast_edit)
  end

  class Scope < Scope
    def resolve
      scope.where(account_id: token.authorized_account_ids(:read_private))
    end
  end
end
