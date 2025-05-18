Rails.application.routes.draw do
  get "footers/terms_of_service"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # ヘルスチェック用のルート
  get "up", to: "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # PWA関連のルート
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest

  # リソースルート
  resources :sleep_logs, only: [ :index, :new, :edit, :update, :create, :destroy ]

  # 利用規約
  get "/footers/terms_of_service", to: "footers#terms_of_service"
  # プライバシーポリシー
  get "/footers/privacy_policy", to: "footers#privacy_policy"

  # ログイン機能
  devise_for :users, controllers: {
    registrations: "users/registrations", # ユーザー設定など用
    passwords: "users/passwords", # パスワードリセット用
    omniauth_callbacks: "users/omniauth_callbacks" # Google認証用
  }

  devise_scope :user do
    # ログイン・ログアウト
    get "/users/sign_out", to: "devise/sessions#destroy"
    post "/users/sign_in", to: "devise/sessions#create"
    # ユーザー設定
    get "users/edit_profile", to: "users/registrations#edit_profile"
    patch "users/update_profile", to: "users/registrations#update_profile"
    # パスワード変更
    get "users/edit_password", to: "users/registrations#edit_password"
    patch "users/update_password", to: "users/registrations#update_password"
    # 退会機能
    get "users/unsubscribe_confirm", to: "users/registrations#unsubscribe_confirm"
    delete "users/destroy", to: "users/registrations#destroy"
    # Defines the root path route ('/') トップページ
    root to: "devise/sessions#new"
  end
end
