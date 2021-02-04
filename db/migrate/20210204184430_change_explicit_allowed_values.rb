class ChangeExplicitAllowedValues < ActiveRecord::Migration

  NOT_EXPLICITS = [nil, '', 'no', 'clean', 'false'].freeze
  EXPLICITS = %w(yes explicit true).freeze

  # as of 2021-02-04, only true/false are allowed
  # https://help.apple.com/itc/podcasts_connect/#/itcb54353390
  def up
    Podcast.where(explicit: NOT_EXPLICITS).update_all(explicit: 'false')
    Podcast.where(explicit: EXPLICITS).update_all(explicit: 'true')

    # channel level explicit now required - error on anything else
    bad = Podcast.where.not(explicit: %w(true false))
    raise "Bad podcast explicits: #{bad.inspect}" if bad.any?

    # set episodes where different than podcast
    Podcast.all.each do |p|
      if p.explicit == 'false'
        p.episodes.where(explicit: NOT_EXPLICITS).update_all(explicit: nil)
        p.episodes.where(explicit: EXPLICITS).update_all(explicit: 'true')
      else
        p.episodes.where(explicit: NOT_EXPLICITS).update_all(explicit: 'false')
        p.episodes.where(explicit: EXPLICITS).update_all(explicit: nil)
      end
    end

    # allow nils this time, but nothing else
    bad = Episode.where.not(explicit: [nil, 'true', 'false'])
    raise "Bad episode explicits: #{bad.inspect}" if bad.any?
  end
end
