class ChangeExplicitAllowedValues < ActiveRecord::Migration[4.2]
  NOT_EXPLICITS = [nil, "", "no", "clean", "false"].freeze
  EXPLICITS = %w[yes explicit true].freeze

  # as of 2021-02-04, only true/false are allowed
  # https://help.apple.com/itc/podcasts_connect/#/itcb54353390
  def up
    n1 = Podcast.with_deleted.where(explicit: NOT_EXPLICITS).update_all(explicit: "false")
    n2 = Podcast.with_deleted.where(explicit: EXPLICITS).update_all(explicit: "true")

    # channel level explicit now required - error on anything else
    bad = Podcast.with_deleted.where("explicit IS NULL OR explicit NOT IN (?)", %w[true false])
    raise "Bad podcast explicits: #{bad.pluck(:id).inspect}" if bad.any?

    # get a full list of existing podcast ids
    not_explicit_ids = Podcast.with_deleted.where(explicit: "false").pluck(:id)
    explicit_ids = Podcast.with_deleted.where(explicit: "true").pluck(:id)
    all_ids = not_explicit_ids + explicit_ids

    # set episodes where different than podcast
    n3 = Episode.with_deleted.where(podcast_id: not_explicit_ids, explicit: NOT_EXPLICITS).update_all(explicit: nil)
    n4 = Episode.with_deleted.where(podcast_id: not_explicit_ids, explicit: EXPLICITS).update_all(explicit: "true")
    n5 = Episode.with_deleted.where(podcast_id: explicit_ids, explicit: NOT_EXPLICITS).update_all(explicit: "false")
    n6 = Episode.with_deleted.where(podcast_id: explicit_ids, explicit: EXPLICITS).update_all(explicit: nil)

    # set any episodes orphaned from their podcasts (for some reason)
    orphaned = "podcast_id IS NULL OR podcast_id NOT IN (?)"
    n7 = Episode.with_deleted.where(explicit: NOT_EXPLICITS).where(orphaned, all_ids).update_all(explicit: "false")
    n8 = Episode.with_deleted.where(explicit: EXPLICITS).where(orphaned, all_ids).update_all(explicit: "true")

    # allow nils this time, but nothing else
    bad = Episode.with_deleted.where.not(explicit: [nil, "true", "false"])
    raise "Bad episode explicits: #{bad.pluck(:id).inspect}" if bad.any?

    # stats
    puts "Total of #{Podcast.with_deleted.count} podcasts, #{Episode.with_deleted.count} episodes"
    puts "  #{n1} clean podcasts"
    puts "    #{n3} clean (nil) episodes"
    puts "    #{n4} explicit (true) episodes"
    puts "  #{n2} explicit podcasts"
    puts "    #{n5} clean (false) episodes"
    puts "    #{n6} explicit (nil) episodes"
    puts "  #{n7} orphaned clean (false) episodes"
    puts "  #{n8} orphaned explicit (true) episodes"
  end

  def down
    Podcast.with_deleted.where(explicit: NOT_EXPLICITS).update_all(explicit: "clean")
    Podcast.with_deleted.where(explicit: EXPLICITS).update_all(explicit: "explicit")
    Episode.with_deleted.where(explicit: NOT_EXPLICITS).update_all(explicit: "clean")
    Episode.with_deleted.where(explicit: EXPLICITS).update_all(explicit: "explicit")
  end
end
