Rails.application.routes.draw do
  # トップページ
  root to: "headers#how_to_use"

  # ヘッダー
  get "/headers/how_to_use", to: "headers#how_to_use"

  # フッター
  scope :footers do
    # おといあわせ
    get "/footers/contact_form", to: "footers#contact_form"
    post "/footers/contact_form", to: "footers#create"
    # 利用規約
    get "/footers/terms_of_service", to: "footers#terms_of_service"
    # プライバシーポリシー
    get "/footers/privacy_policy", to: "footers#privacy_policy"
  end

  # Devise(ユーザー認証)
  devise_for :users, controllers: {
    registrations: "users/registrations", # 新規登録
    sessions: "users/sessions", # ログイン
    passwords: "users/passwords", # パスワードリセット用
    omniauth_callbacks: "users/omniauth_callbacks" # Google認証用
  }

  # Devise(カスタマイズ)
  devise_scope :user do
    # ユーザー設定
    get "users/edit_profile", to: "users/registrations#edit_profile"
    patch "users/update_profile", to: "users/registrations#update_profile"
    # パスワード変更
    get "users/edit_password", to: "users/registrations#edit_password"
    patch "users/update_password", to: "users/registrations#update_password"
    # 退会機能
    get "users/unsubscribe_confirm", to: "users/registrations#unsubscribe_confirm"
    delete "users/destroy", to: "users/registrations#destroy"
  end

  # リソースルート
  resources :sleep_logs, only: [ :index, :new, :edit, :update, :create, :destroy ]

  # ヘルスチェック用のルート 正常に稼働しているか外部から監視
  get "up", to: "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # PWA関連のルート だけど実質使っていない。スマホ向けのプログレッシブwebアプリ, webアプリマニフェストらしい
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
end
