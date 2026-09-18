class PodcastIntegrationsController < ApplicationController
  before_action :set_podcast
  before_action :authorize_podcast_access, only: [:create_apple_key, :destroy_apple_key]
  before_action :set_apple_key, only: :destroy_apple_key

  def show
    authorize @podcast
    load_apple_credentials
  end

  def update
    authorize @podcast
    load_apple_credentials

    submitted_key_id = podcast_integration_params[:apple_key_id].presence
    selected_key = @apple_keys.find_by(id: submitted_key_id) if submitted_key_id

    if submitted_key_id && selected_key.nil?
      @podcast.errors.add(:apple_key, t(".unavailable"))
    elsif selected_key == @podcast.apple_key
      return redirect_to podcast_integrations_path(@podcast), notice: t(".notice")
    elsif selected_key_can_access_connected_shows?(selected_key) && @podcast.update(apple_key: selected_key)
      return redirect_to podcast_integrations_path(@podcast), notice: t(".notice")
    end

    flash.now[:error] = t(".error")
    render :show, status: :unprocessable_entity
  end

  def create_apple_key
    @apple_key = Apple::Key.new(apple_key_params.merge(account_id: @podcast.account_id))
    authorize @apple_key, :create?

    if @apple_key.save
      redirect_to podcast_integrations_path(@podcast), notice: t(".notice")
    else
      load_apple_credentials
      flash.now[:error] = t(".error")
      render :show, status: :unprocessable_entity
    end
  end

  def destroy_apple_key
    authorize @apple_key, :destroy?

    if @apple_key.podcasts.with_deleted.exists?
      redirect_to podcast_integrations_path(@podcast), alert: t(".in_use")
    elsif @apple_key.destroy
      redirect_to podcast_integrations_path(@podcast), notice: t(".notice")
    else
      redirect_to podcast_integrations_path(@podcast), alert: t(".error")
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  rescue ActiveRecord::RecordNotFound => error
    render_not_found(error)
  end

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

  def authorize_podcast_access
    authorize @podcast, :show?
  end

  def set_apple_key
    @apple_key = policy_scope(Apple::Key)
      .for_account(@podcast.account_id)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound => error
    render_not_found(error)
  end

  def apple_key_params
    params.require(:apple_key).permit(:provider_id, :key_id, :key_pem_b64)
  end

  def podcast_integration_params
    params.require(:podcast).permit(:apple_key_id)
  end

  def selected_key_can_access_connected_shows?(selected_key)
    return true if @connected_apple_show_ids.empty?

    unless selected_key
      @podcast.errors.add(:apple_key, t(".required"))
      return false
    end

    missing_show_ids = selected_key.inaccessible_show_ids(@connected_apple_show_ids)
    return true if missing_show_ids.empty?

    @podcast.errors.add(:apple_key, t(".inaccessible", show_ids: missing_show_ids.to_sentence))
    false
  rescue => error
    Rails.logger.error(
      "Unable to verify Apple credential for podcast",
      podcast_id: @podcast.id,
      apple_key_id: selected_key&.id,
      error: error
    )
    @podcast.errors.add(:apple_key, t(".verification_failed"))
    false
  end
end
