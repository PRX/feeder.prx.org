class Content < MediaResource
  def replace_resources!
    Content.where(episode_id: episode_id, position: position).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end
end
