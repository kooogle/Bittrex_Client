class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  before_action :cookie_user_auth
  protect_from_forgery with: :null_session

  rescue_from CanCan::AccessDenied do |exception|
    if current_user
      respond_to do |format|
        format.html { redirect_to root_path }
      end
    else
      respond_to do |format|
        format.html { redirect_to sign_in_path }
      end
    end
  end

  def cookie_user_auth
    if current_user.nil? && cookies[:user_id]
      user = User.find cookies.signed[:user_id]
      sign_in(user)
    end
  end

end
