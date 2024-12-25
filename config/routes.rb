Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # ヘルスチェック用のルート
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  # PWA関連のルート
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/") トップページ
  root to: "sleep_logs#index"
  # リソースルート
  resources :sleep_logs, only: [:index, :show, :edit, :update, :create, :destroy]

  # ログイン機能
  devise_for :users

  devise_scope :user do
    get "/users/sign_out" => "devise/sessions#destroy"
    post "/users/sign_in" => "devise/sessions#create"
  end
end
