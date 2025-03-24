# RemoveChartable.new.fix_feeds
class RemoveChartable
  PRX_SWAP_FM_FEEDS = [424, 398, 4192, 181, 258, 268, 3334, 308, 4885, 279, 5051, 44, 144]

  SWAP_FM_PREFIX = "tracking.swap.fm/track/sblTq32fyWAjsHzze2LG/"

  DEBUG = true

  def fix_feeds
    chartable_feeds.each do |feed|
      puts "\npodcast: #{feed.podcast.id}: #{feed.podcast.title}, feed: #{feed.id}"
      new_prefix = remove_chartable(feed.enclosure_prefix)

      if PRX_SWAP_FM_FEEDS.include?(feed.id)
        new_prefix = add_swap_fm(new_prefix)
      end

      puts "fix_feeds:\n\t'#{feed.enclosure_prefix}'\n\t'#{new_prefix}'\n"

      if (new_prefix != feed.enclosure_prefix) && !DEBUG
        feed.update(enclosure_prefix: new_prefix)
        feed.podcast.publish!
      end
    end
    puts "done!"
  end

  def chartable_feeds
    Feed.where("enclosure_prefix like '%chrt.fm%' or enclosure_prefix like '%chtbl.com%'")
  end

  def add_swap_fm(prefix)
    if prefix.include?(SWAP_FM_PREFIX)
      puts "add_swap_fm: swap.fm prefix already present"
      return prefix
    end

    fixed = (prefix || "").gsub("https:/", "")
    fixed = if fixed.blank?
      "https://#{SWAP_FM_PREFIX}"
    else
      "#{fixed}/#{SWAP_FM_PREFIX}"
    end
    fixed = fixed.squeeze("/")

    # get rid of any leading slashes
    fixed = fixed.sub(/^\/+/, "")

    fixed = (fixed.blank? || fixed == "/") ? nil : "https://#{fixed}"
    puts "add_swap_fm: #{prefix} -> #{fixed}"
    fixed
  end

  def remove_chartable(prefix)
    # remove https:/ anywhere in the prefix (we'll put it back!)
    fixed = (prefix || "").gsub("https:/", "")

    # remove the chartable prefix
    fixed = fixed.gsub(/(chrt\.fm|chtbl\.com)\/track\/\w+/, "")

    # remove any duplicate slashes left over
    fixed = fixed.squeeze("/")

    # get rid of any leading slashes
    fixed = fixed.sub(/^\/+/, "")

    # if all that is left is a single slash, this is nil
    # otherwise, add back that protocol
    fixed = (fixed.blank? || fixed == "/") ? nil : "https://#{fixed}"
    puts "remove_chartable: #{prefix} -> #{fixed}"
    fixed
  end
end
