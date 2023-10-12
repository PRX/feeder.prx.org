module ImportsHelper
  def import_progress(podcast_import)
    if podcast_import.feed_episode_count.present?
      ((podcast_import.episode_imports.done.count.to_f / podcast_import.feed_episode_count.to_f) * 100).ceil.to_s
    else
      "0"
    end
  end
end
