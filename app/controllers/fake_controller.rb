class FakeController < ApplicationController
  def index
  end

  def show
    @fake = "some/fake/model/#{params[:id]}"

    if params[:id] == "8888"
      flash.now[:notice] = "This is a notice, okay?"
    elsif params[:id] == "9999"
      authorize Podcast.new, :create?
    end
  end
end
