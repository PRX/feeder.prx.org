class AppleKeysController < ApplicationController
  before_action :set_podcast

  def create
    @apple_key = Apple::Key.new(apple_key_params.merge(account_id: @podcast.account_id))
    authorize @apple_key

    if @apple_key.save
      redirect_to podcast_integrations_path(@podcast), notice: t(".notice")
    else
      @apple_keys = policy_scope(Apple::Key).for_account(@podcast.account_id).order(:created_at)
      flash.now[:error] = t(".error")
      render "podcast_integrations/show", status: :unprocessable_entity
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
end
