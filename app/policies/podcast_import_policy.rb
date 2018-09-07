class PodcastImportPolicy < AccountablePolicy
  def verify_rss?
    true
  end
end
