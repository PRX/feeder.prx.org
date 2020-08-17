class PodcastImportPolicy < AccountablePolicy
  def initialize(token, import)
    super(token, import, [:story, :series])
  end

  def verify_rss?
    true
  end
end
