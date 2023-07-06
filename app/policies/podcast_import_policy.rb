class PodcastImportPolicy < PodcastPolicy
  def index?
    PodcastPolicy.new(token, resource.podcast).new?
  end

  def create?
    PodcastPolicy.new(token, resource.podcast).create?
  end

  private

  def account_id
    resource.podcast.account_id
  end

  def account_id_was
    resource.podcast.account_id_was
  end

  class Scope < Scope
    def resolve
      podcast_policy_scope = PodcastPolicy::Scope.new(token, Podcast.all).resolve
      PodcastImport.from(PodcastImport.joins(:podcast).where(podcast: podcast_policy_scope), :podcast_imports)
    end
  end
end
