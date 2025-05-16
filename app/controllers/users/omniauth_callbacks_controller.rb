# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # binding.pry
  def google_oauth2
    callback_for(:google)
  end

  def callback_for(provider)
    @omniauth = request.env["omniauth.auth"]
    info = User.find_oauth(@omniauth)
    @user = info[:user]
    # もしUser情報があってSNSと紐づいていればログイン、User情報がなければ登録を促す
    if @user.persisted? # User情報が保存できているか？
      sign_in_and_redirect @user, event: :authentication
      # is_navigational_formatはフラッシュメッセージを発行する必要があるかどうか確認する
      # capitalizeは先頭文字を大文字に、それ以外を小文字にする
      set_flash_message(:notice, :success, kind: provider.to_s.capitalize) if is_navigational_format?
    else
      # TODO: これだと新規登録画面で残りの情報（ユーザー名など）を入れさせるスタイルになるので、自動で登録されるシステムにしたい
      @sns = info[:sns]
      render "users/registrations/new" # ビューを表示
    end
  end

  def failure
    redirect_to root_path and return
  end

  # You should configure your model like this:
  # devise :omniauthable, omniauth_providers: [:twitter]

  # You should also create an action method in this controller like this:
  # def twitter
  # end

  # More info at:
  # https://github.com/heartcombo/devise#omniauth

  # GET|POST /resource/auth/twitter
  # def passthru
  #   super
  # end

  # GET|POST /users/auth/twitter/callback
  # def failure
  #   super
  # end

  # protected

  # The path used when OmniAuth fails
  # def after_omniauth_failure_path_for(scope)
  #   super(scope)
  # end
end
