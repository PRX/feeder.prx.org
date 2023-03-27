require "test_helper"

describe PodcastPlanner do
  let(:podcast) { create(:podcast) }
  let(:planner) { PodcastPlanner.new(podcast_id: podcast.id) }

  describe "guard methods" do
    it "ready_to_select_weeks?" do
      assert_equal planner.ready_to_select_weeks?, false

      planner.week_condition = "periodic"
      assert_equal planner.ready_to_select_weeks?, false
      planner.period = 1
      assert_equal planner.ready_to_select_weeks?, true

      planner.week_condition = "monthly"
      assert_equal planner.ready_to_select_weeks?, false
      planner.monthly_weeks = [1]
      assert_equal planner.ready_to_select_weeks?, true
      planner.monthly_weeks = [1, 2]
      assert_equal planner.ready_to_select_weeks?, true
    end

    it "ready_to_select_date_range?" do
      assert_equal planner.ready_to_select_date_range?, false

      planner.date_range_condition = "episodes"
      assert_equal planner.ready_to_select_date_range?, false
      planner.number_of_episodes = 10
      assert_equal planner.ready_to_select_date_range?, true

      planner.date_range_condition = "date"
      assert_equal planner.ready_to_select_date_range?, false
      planner.start_date = DateTime.new(2001, 2, 3)
      planner.end_date = DateTime.new(2001, 2, 1)
      assert_equal planner.ready_to_select_date_range?, false
      planner.end_date = DateTime.new(2001, 2, 3)
      assert_equal planner.ready_to_select_date_range?, false
      planner.end_date = DateTime.new(2001, 2, 4)
      assert_equal planner.ready_to_select_date_range?, true
    end

    it "ready_to_generate_dates?" do
      assert_equal planner.ready_to_generate_dates?, false

      planner.selected_days = [1, 3]
      assert_equal planner.ready_to_generate_dates?, false

      planner.week_condition = "monthly"
      planner.monthly_weeks = [2, 4]
      assert_equal planner.ready_to_generate_dates?, false

      planner.date_range_condition = "episodes"
      planner.number_of_episodes = 10
      assert_equal planner.ready_to_generate_dates?, true

      planner.selected_days = []
      assert_equal planner.ready_to_generate_dates?, false

      planner.selected_days = [1, 3]
      planner.week_condition = "periodic"
      assert_equal planner.ready_to_generate_dates?, false
      planner.period = 1
      assert_equal planner.ready_to_generate_dates?, true

      planner.date_range_condition = "date"
      assert_equal planner.ready_to_generate_dates?, false
      planner.start_date = DateTime.new(2001, 2, 3)
      planner.end_date = DateTime.new(2001, 2, 4)
      assert_equal planner.ready_to_generate_dates?, true
    end

    it "ready_to_generate_drafts?" do
      assert_equal planner.ready_to_generate_drafts?, false

      dates = []
      5.times do |i|
        dates.push(DateTime.new(2001, 2, 3) + i.weeks)
      end
      planner.dates = dates
      assert_equal planner.ready_to_generate_drafts?, false

      planner.publish_time = DateTime.new(2001, 2, 3, 4, 30)
      assert_equal planner.ready_to_generate_drafts?, false

      planner.segment_count = 2
      assert_equal planner.ready_to_generate_drafts?, true

      planner.dates = []
      assert_equal planner.ready_to_generate_drafts?, false

      planner.dates = dates
      planner.publish_time = nil
      assert_equal planner.ready_to_generate_drafts?, false
    end
  end

  describe "generators" do
    describe "generate_dates!" do
      before do
        # selected Monday, Wednesday
        planner.selected_days = [1, 3]
        # Thursday, March 3, 2001
        planner.start_date = DateTime.new(2001, 3, 1)
      end

      describe "generate_dates_by_remaining_episodes" do
        before do
          planner.date_range_condition = "episodes"
          planner.number_of_episodes = 10
        end

        it "calculates by week of the month if monthly" do
          assert_nil planner.dates
          planner.week_condition = "monthly"

          # first week of every month
          planner.monthly_weeks = [1]
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Wednesday, March 7
            DateTime.new(2001, 3, 7),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Wednesday, April 4
            DateTime.new(2001, 4, 4),
            # Wednesday, May 2
            DateTime.new(2001, 5, 2),
            # Monday, May 7
            DateTime.new(2001, 5, 7),
            # Monday, June 4
            DateTime.new(2001, 6, 4),
            # Wednesday, June 6
            DateTime.new(2001, 6, 6),
            # Monday, July 2
            DateTime.new(2001, 7, 2),
            # Wednesday, July 4
            DateTime.new(2001, 7, 4)
          ]
          assert_equal planner.dates.length, 10

          # first and third weeks of every month
          planner.monthly_weeks = [1, 3]
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Wednesday, March 7
            DateTime.new(2001, 3, 7),
            # Monday, March 19
            DateTime.new(2001, 3, 19),
            # Wednesday, Match 21
            DateTime.new(2001, 3, 21),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Wednesday, April 4
            DateTime.new(2001, 4, 4),
            # Monday, April 16
            DateTime.new(2001, 4, 16),
            # Wednesday, April 18
            DateTime.new(2001, 4, 18),
            # Wednesday, May 2
            DateTime.new(2001, 5, 2),
            # Monday, May 7
            DateTime.new(2001, 5, 7)
          ]
          assert_equal planner.dates.length, 10
        end

        it "calculates by period if periodic" do
          assert_nil planner.dates
          planner.week_condition = "periodic"

          # every week
          planner.period = 1
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Wednesday, March 7
            DateTime.new(2001, 3, 7),
            # Monday, March 12
            DateTime.new(2001, 3, 12),
            # Wednesday, March 14
            DateTime.new(2001, 3, 14),
            # Monday, March 19
            DateTime.new(2001, 3, 19),
            # Wednesday, March 21
            DateTime.new(2001, 3, 21),
            # Monday, March 26
            DateTime.new(2001, 3, 26),
            # Wednesday, March 28
            DateTime.new(2001, 3, 28),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Wednesday, April 4
            DateTime.new(2001, 4, 4)
          ]
          assert_equal planner.dates.length, 10

          # every other week
          planner.period = 2
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Wednesday, March 7
            DateTime.new(2001, 3, 7),
            # Monday, March 19
            DateTime.new(2001, 3, 19),
            # Wednesday, March 21
            DateTime.new(2001, 3, 21),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Wednesday, April 4
            DateTime.new(2001, 4, 4),
            # Monday, April 16
            DateTime.new(2001, 4, 16),
            # Wednesday, April 18
            DateTime.new(2001, 4, 18),
            # Monday, April 30
            DateTime.new(2001, 4, 30),
            # Wednesday, May 2
            DateTime.new(2001, 5, 2)
          ]
          assert_equal planner.dates.length, 10
        end
      end

      describe "generate_dates_by_end_date" do
        before do
          planner.date_range_condition = "date"
          # Friday, August 31, 2001. about 6 months range
          planner.end_date = DateTime.new(2001, 8, 31)
          # just mondays, for brevity
          planner.selected_days = [1]
        end

        it "calculates by week of the month if monthly" do
          assert_nil planner.dates
          planner.week_condition = "monthly"

          # first week of every month
          planner.monthly_weeks = [1]
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Monday, May 7
            DateTime.new(2001, 5, 7),
            # Monday, June 4
            DateTime.new(2001, 6, 4),
            # Monday, July 2
            DateTime.new(2001, 7, 2),
            # Monday, August 6
            DateTime.new(2001, 8, 6)
          ]
          planner.dates.each do |date|
            assert_equal date > planner.start_date, true
            assert_equal date <= planner.end_date, true
          end

          # first and third weeks of every month
          planner.monthly_weeks = [1, 3]
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Monday, March 19
            DateTime.new(2001, 3, 19),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Monday, April 16
            DateTime.new(2001, 4, 16),
            # Monday, May 7
            DateTime.new(2001, 5, 7),
            # Monday, May 21
            DateTime.new(2001, 5, 21),
            # Monday, June 4
            DateTime.new(2001, 6, 4),
            # Monday, June 18
            DateTime.new(2001, 6, 18),
            # Monday, July 2
            DateTime.new(2001, 7, 2),
            # Monday, July 16
            DateTime.new(2001, 7, 16),
            # Monday, August 6
            DateTime.new(2001, 8, 6),
            # Monday, August 20
            DateTime.new(2001, 8, 20)
          ]
          planner.dates.each do |date|
            assert_equal date > planner.start_date, true
            assert_equal date <= planner.end_date, true
          end
        end

        it "calculates by period if periodic" do
          assert_nil planner.dates
          planner.week_condition = "periodic"

          # every other week
          planner.period = 2
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Monday, March 19
            DateTime.new(2001, 3, 19),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Monday, April 16
            DateTime.new(2001, 4, 16),
            # Monday, April 30
            DateTime.new(2001, 4, 30),
            # Monday, May 14
            DateTime.new(2001, 5, 14),
            # Monday, May 28
            DateTime.new(2001, 5, 28),
            # Monday, June 11
            DateTime.new(2001, 6, 11),
            # Monday, June 25
            DateTime.new(2001, 6, 25),
            # Monday, July 9
            DateTime.new(2001, 7, 9),
            # Monday, July 23
            DateTime.new(2001, 7, 23),
            # Monday, August 6
            DateTime.new(2001, 8, 6),
            # Monday, August 20
            DateTime.new(2001, 8, 20)
          ]
          planner.dates.each do |date|
            assert_equal date > planner.start_date, true
            assert_equal date <= planner.end_date, true
          end

          # every 4 weeks
          planner.period = 4
          planner.generate_dates!
          assert_equal planner.dates, [
            # Monday, March 5
            DateTime.new(2001, 3, 5),
            # Monday, April 2
            DateTime.new(2001, 4, 2),
            # Monday, April 30
            DateTime.new(2001, 4, 30),
            # Monday, May 28
            DateTime.new(2001, 5, 28),
            # Monday, June 25
            DateTime.new(2001, 6, 25),
            # Monday, July 23
            DateTime.new(2001, 7, 23),
            # Monday, August 20
            DateTime.new(2001, 8, 20)
          ]
          planner.dates.each do |date|
            assert_equal date > planner.start_date, true
            assert_equal date <= planner.end_date, true
          end
        end
      end
    end
  end
end
