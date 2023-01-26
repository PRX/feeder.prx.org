class FakeController < ApplicationController
  def index
  end

  def show
    @episode = Episode.new(title: "Fake Episode #{params[:id]}")

    if params[:id] == "8888"
      flash.now[:notice] = "This is a notice, okay?"
    elsif params[:id] == "9999"
      authorize Podcast.new, :create?
    end
  end

  def create
    @episode = Episode.new(fake_params)

    if @episode.valid?
      redirect_to fake_path, notice: "I'm not actually going to create that"
    else
      @episode.errors.add(:title, "Fake validation message")
      flash.now[:error] = "There was a problem saving the Episode"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def fake_params
    params.require(:episode).permit(:title, :itunes_type)
  end
end
