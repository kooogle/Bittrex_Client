class Api::WechatsController < ApplicationController

  def auth
    render text:params[:echostr]
  end

end