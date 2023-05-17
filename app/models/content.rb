class Content < MediaResource
  after_save :publish_podcast

  def publish_podcast
    episode&.podcast&.publish! if status_complete? && status_previously_changed?
  end

  def replace_resources!
    Content.where(episode_id: episode_id, position: position).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end
end
