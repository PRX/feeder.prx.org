class EventResponder
  def initialize(episode_id)
    @episode = Episode.find_by(prx_id: episode_id)
    @podcast = @episode.podcast
  end

  def remove
    @episode.destroy
    update_podcast
  end

  def edit
    @episode.touch
    update_podcast
  end

  def self.remove(episode_id)
    new(episode_id).remove
  end

  def self.edit(episode_id)
    new(episode_id).edit
  end

  private

  def update_podcast
    DateUpdater.both_dates(@podcast)
  end
end
