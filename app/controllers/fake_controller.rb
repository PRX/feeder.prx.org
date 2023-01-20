class FakeController < ApplicationController
  def index; end

  def show
    @fake = "some/fake/model/#{params[:id]}"
  end
end
