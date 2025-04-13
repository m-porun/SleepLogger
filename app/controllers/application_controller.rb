class ApplicationController < ActionController::Base
  # ログイン機能でnameパラメーターを許可する
  before_action :configure_permitted_parameters, if: :devise_controller?
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def configure_permitted_parameters
    # ユーザー登録時にnameのストロングパラメーターを追加
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    # ユーザー編集時にnameのストロングパラメーターを追加
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end


  # ログイン後のリダイレクト先
  def after_sign_in_path_for(resource_or_scope)
    sleep_logs_path
  end

  # ログアウト後のリダイレクト先
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path # ここを好きなパスに変更
  end
end
