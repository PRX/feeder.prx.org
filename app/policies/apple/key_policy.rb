class Apple::KeyPolicy < ApplicationPolicy
  def new?
    create?
  end

  def show?
    Apple::DelegatedDeliveryConfigPolicy.new(token, resource.delegated_delivery_config).show?
  end

  def create?
    Apple::DelegatedDeliveryConfigPolicy.new(token, resource.delegated_delivery_config).create?
  end

  def update?
    Apple::DelegatedDeliveryConfigPolicy.new(token, resource.delegated_delivery_config).update?
  end
end
