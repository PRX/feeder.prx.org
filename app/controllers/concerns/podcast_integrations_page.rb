module PodcastIntegrationsPage
  extend ActiveSupport::Concern

  private

  def load_apple_credentials
    @apple_keys = policy_scope(Apple::Key)
      .for_account(@podcast.account_id)
      .includes(:podcasts)
      .order(:created_at)
    @apple_key ||= Apple::Key.new(account_id: @podcast.account_id)
    @connected_apple_show_ids = @podcast.feeds
      .joins(:apple_show_feed_binding)
      .distinct
      .pluck("apple_show_feed_bindings.apple_show_id")
  end
end
