Rails.application.routes.draw do
  if Rails.env.development?
    mount MissionControl::Jobs::Engine, at: "/jobs"
    get "/dev", to: "dev_tools#show", as: :dev_tools
    post "/dev/test_job", to: "dev_tools#test_job", as: :dev_tools_test_job
    post "/dev/reindex_search", to: "dev_tools#reindex_search", as: :dev_tools_reindex_search
  end

  get "search", to: "search#index", as: :search

  resource :session
  resources :passwords, param: :token
  resource :profile, only: %i[edit update]
  patch "profile/display_preferences", to: "profiles#update_display_preferences", as: :profile_display_preferences
  scope :admin, as: :admin, module: :admin_area do
    resource :settings, only: %i[ show update ]
    resources :users, only: %i[index show edit update]
    resources :tax_codes
    resources :suppliers
    resources :audits, only: %i[index show], path: "audits"
  end

  resources :products do
    resources :product_variants, only: %i[ show new create edit update destroy ] do
      member do
        delete :purge_image
      end
    end
  end
  resources :services
  resources :customers
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA: manifest and service worker for installable app
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root "dashboard#index"
end
