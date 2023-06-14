class EpisodePolicy < ApplicationPolicy
  def create?
    update?
  end

  def show?
    authorized?(:read_private)
  end

  def update?
    authorized?(:episode) || (authorized?(:episode_draft) && resource.draft? && resource.was_draft?)
  end

  def destroy?
    update?
  end

  private

  def account_id
    resource&.podcast&.account_id
  end

  def account_id_was
    if resource.podcast_id_changed? && resource.podcast_id_was.present?
      Podcast.find(resource.podcast_id_was)
    else
      resource.podcast
    end&.account_id_was
  end

  class Scope < Scope
    def resolve
      # TODO: this is hacky
      if token.globally_authorized?("read-private")
        scope.all
      else
        uris = token.authorized_account_ids(:read_private).map { |id| "/api/v1/accounts/#{id}" }
        scope.joins(:podcast).where(podcasts: {prx_account_uri: uris})
      end
    end
  end
end
