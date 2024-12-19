# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]

  ##### コメントアウト中！　ログイン・ログアウトできなかったら戻してね
  # GET /resource/sign_in
  # def new
  #   root_path
  # end

  # # POST /resource/sign_in
  # def create
  #   root_path
  # end

  # # DELETE /resource/sign_out
  # def destroy
  #   root_path
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
