class UncutVideo < Uncut
  validates :medium, inclusion: {in: %w[video]}, if: :status_complete?

  def copy_media(force = false)
    if force || needs_copy?
      Tasks::CopyMediaTask.start!(self)
    end
  end

  def build_content(seg)
    UncutContent.new(original_url: url, segmentation: seg)
  end
end
