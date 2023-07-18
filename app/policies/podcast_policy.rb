class PodcastPolicy < ApplicationPolicy
  def new?
    token&.authorized_account_ids(:podcast_create).present?
  end

  def create?
    authorized?(:podcast_create)
  end

  def show?
    authorized?(:read_private)
  end

  def update?
    authorized?(:podcast_edit)
  end

  def destroy?
    if authorized?(:podcast_delete)
      # must be new-ish OR have 0 published episodes
      resource.created_at > 1.day.ago || resource.episodes.published.none?
    else
      false
    end
  end

  private

  def account_id
    resource.account_id
  end

  def account_id_was
    resource.account_id_was
  end

  class Scope < Scope
    def resolve
      # TODO: this is hacky
      if token.globally_authorized?("read-private")
        scope.all
      else
        uris = token.authorized_account_ids(:read_private).map { |id| "/api/v1/accounts/#{id}" }
        scope.where(prx_account_uri: uris)
      end
    end
  end
end
