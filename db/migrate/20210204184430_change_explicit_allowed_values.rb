class ChangeExplicitAllowedValues < ActiveRecord::Migration

  # as of 2021-02-04, only true/false are allowed
  # https://help.apple.com/itc/podcasts_connect/#/itcb54353390
  def up
    Podcast.where(explicit: [nil, '', 'no', 'clean']).update_all(explicit: 'false')
    Podcast.where(explicit: %w(yes explicit)).update_all(explicit: 'true')

    # channel level explicit now required - error on anything else
    bad = Podcast.where.not(explicit: %w(true false))
    raise "Bad podcast statuses: #{bad.inspect}" if bad.any?

    # set episodes where different than podcast
    Podcast.all.each do |p|
      if p.explicit == 'false'
        p.episodes.where(explicit: [nil, '', 'no', 'clean', 'false']).update_all(explicit: nil)
        p.episodes.where.not(explicit: [nil, '', 'no', 'clean', 'false']).update_all(explicit: 'true')
      else
        p.episodes.where(explicit: [nil, '', 'no', 'clean', 'false']).update_all(explicit: 'false')
        p.episodes.where.not(explicit: [nil, '', 'no', 'clean', 'false']).update_all(explicit: nil)
      end
    end
  end
end
