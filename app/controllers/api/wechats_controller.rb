class Api::WechatsController < ApplicationController

  def auth
    render json:{echostr:params[:echostr]}
  end

end