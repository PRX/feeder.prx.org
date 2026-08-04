class PodcastIntegrationsController < ApplicationController
  before_action :set_podcast

  def show
    @apple_keys = policy_scope(Apple::Key).for_account(@podcast.account_id).order(:created_at)
    @apple_key = Apple::Key.new(account_id: @podcast.account_id)
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  rescue ActiveRecord::RecordNotFound => error
    render_not_found(error)
  end
end
