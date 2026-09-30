class AppleKeysController < ApplicationController
  include PodcastIntegrationsPage

  before_action :set_podcast
  before_action :set_apple_key, only: :destroy

  def create
    @apple_key = Apple::Key.new(apple_key_params.merge(account_id: @podcast.account_id))
    authorize @apple_key, :create?

    if @apple_key.save
      redirect_to podcast_integrations_path(@podcast), notice: t(".notice")
    else
      load_apple_credentials
      flash.now[:error] = t(".error")
      render "podcast_integrations/show", status: :unprocessable_entity
    end
  end

  def destroy
    authorize @apple_key, :destroy?

    if @apple_key.destroy
      redirect_to podcast_integrations_path(@podcast), notice: t(".notice")
    else
      alert = @apple_key.errors.full_messages.to_sentence.presence || t(".error")
      redirect_to podcast_integrations_path(@podcast), alert: alert
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  rescue ActiveRecord::RecordNotFound => error
    render_not_found(error)
  end

  def apple_key_params
    params.require(:apple_key).permit(:provider_id, :key_id, :key_pem_b64)
  end

  def set_apple_key
    @apple_key = policy_scope(Apple::Key)
      .for_account(@podcast.account_id)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound => error
    render_not_found(error)
  end
end
