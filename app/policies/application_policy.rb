class ApplicationPolicy < Struct.new(:token, :resource)
  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    update?
  end
end
