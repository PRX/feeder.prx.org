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


  private

  def authorized?(scope)
    if account_id_was.present? && account_id_was != account_id
      token&.authorized?(account_id, scope) && token&.authorized?(account_id_was, scope)
    else
      token&.authorized?(account_id, scope)
    end
  end

  def account_id
    resource.account_id
  end

  def account_id_was
    nil
  end
end
