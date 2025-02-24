class Apple::KeyPolicy < ApplicationPolicy
  def new?
    create?
  end

  def show?
    Apple::ConfigPolicy.new(token, resource.config).show?
  end

  def create?
    Apple::ConfigPolicy.new(token, resource.config).create?
  end

  def update?
    Apple::ConfigPolicy.new(token, resource.config).update?
  end
end
