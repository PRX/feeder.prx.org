module ImportsHelper
  def import_types(import)
    types = t("helpers.label.podcast_import.types").to_a.map(&:reverse)
    unless Feeds::MegaphoneFeed.exists?(podcast: import.podcast)
      types = types.delete_if { |type| type.last == :PodcastMegaphoneImport }
    end
    types
  end

  def import_progress(podcast_import)
    if podcast_import.feed_episode_count.present?
      ((podcast_import.episode_imports.done.count.to_f / podcast_import.feed_episode_count.to_f) * 100).ceil.to_s
    else
      "0"
    end
  end

  def import_timings_pasted?
    params.dig(:podcast_import, :pasted).present?
  end

  def megaphone_podcast_options(import)
    feed = Feeds::MegaphoneFeed.where(podcast: import.podcast).first
    Megaphone::Podcast.list(feed).map do |podcast|
      o = [podcast.title, podcast.id]
      puts o.inspect
      o
    end
  end
end
