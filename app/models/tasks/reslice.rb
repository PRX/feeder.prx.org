def reslice_episode(e)
  e.contents.each do |c|
    if c.slice? && c.status_error? && c.task.options[:Tasks][1][:Format] == "INHERIT"
      ext = File.extname(c.original_url).delete(".")
      c.task.options[:Tasks][1][:Format] = ext.present? ? ext : "mp3"
      c.task.status = "retrying"
      c.task.porter_start!(c.task.options)
      c.task.save!
    end
  end
end
