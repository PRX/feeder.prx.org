class RemoveAppleExcludedCategory < ActiveRecord::Migration[7.0]
  def change
    Apple::Config.all.each do |ac|
      begin
        pub = ac.build_publisher

        eps =
          pub.show.podcast_episodes.filter do |ep|
            next false unless ep.feeder_episode.categories.include?("apple-excluded")
            ep.feeder_episode.update(categories: ep.feeder_episode.categories - ["apple-excluded"])

            true
          end

        pub.poll!(eps)

        Apple::Config.mark_as_delivered!(pub)
      rescue => e
        Rails.logger.error("Error on RemoveAppleExcludedCategory", {error: e.message, backtrace: e.backtrace[0,2].join("\n")})
      end
    end
  end
end
