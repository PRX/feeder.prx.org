class FeedAppleConnectionsController < ApplicationController
  def show
    @podcast = Podcast.find(params[:podcast_id])
    @feed = @podcast.feeds.find(params[:feed_id])
    authorize @feed, :show?
    return head(:not_found) unless @feed.apple_connectable?

    # Keep the form's unsaved selection while the options load.
    selection = params.slice(:selection).permit(:selection)
    @apple_settings = Apple::FeedSettings.new(@feed, selection.key?(:selection) ? {connection: selection[:selection]} : {})
    @apple_connection_options = Apple::ShowFeedBinding.connection_options(@podcast.apple_key, feed: @feed) do
      @apple_show_lookup_failed = true
    end
  rescue ActiveRecord::RecordNotFound => error
    render_not_found(error)
  end
end
