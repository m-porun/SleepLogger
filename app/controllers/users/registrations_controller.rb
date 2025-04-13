# Deviseカスタマイズ用コントローラー
# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # 新規登録時に追加パラメータを許可
  # before_action :configure_sign_up_params, only: [:create]
  # 編集時に追加パラメータを許可
  # before_action :configure_account_update_params, only: [:update]

  # ユーザー設定画面
  def edit_profile
  end

  def update_profile
    if current_user.update(account_update_params)
      flash[:notice] = "ユーザー設定を更新しました"
      redirect_to users_edit_profile_path
    else
      flash.now[:alert] ="なんかユーザー設定にやらかしがあります"
      render :edit_profile
    end
  end

  # パスワード変更画面
  def edit_password
  end

  def update_password
    if current_user.update_with_password(password_update_params)
      # 自動ログアウトさせないように再ログイン
      bypass_sign_in(current_user)
      flash[:notice] = "パスワードを更新しました"
      redirect_to users_edit_password_path
    else
      flash.now[:alert] ="なんかパスワードにやらかしがあります"
      render :edit_password
    end
  end

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  def destroy
    current_user.destroy
    flash[:notice] = "ユーザーを削除しました"
    redirect_to :root
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  # ユーザー設定で許可するパラメーター
  def account_update_params
    params.require(:user).permit(:name, :email)
  end

  # パスワード変更で許可するパラメーター
  def password_update_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
  # 新規登録用：独自のユーザー属性を追加する
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # 更新用：独自のユーザー属性を追加する
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # 新規登録後の遷移先
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # 認証メール待ち中のリダイレクト先
  # def after_inactive_sign_up_path_for(resource)
  #   root_path(resource)
  # end
end
