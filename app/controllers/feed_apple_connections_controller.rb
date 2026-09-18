class FeedAppleConnectionsController < ApplicationController
  def show
    @podcast = Podcast.find(params[:podcast_id])
    @feed = @podcast.feeds.find(params[:feed_id])
    authorize @feed, :show?
    return head(:not_found) unless @feed.public?

    selection = params.slice(:selection).permit(:selection)
    @feed.apple_connection = selection[:selection] if selection.key?(:selection)
    @apple_connection_options = Apple::ShowFeedBinding.connection_options(@podcast.apple_key) do
      @apple_show_lookup_failed = true
    end
  rescue ActiveRecord::RecordNotFound => error
    render_not_found(error)
  end
end
