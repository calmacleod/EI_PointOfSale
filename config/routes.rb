Rails.application.routes.draw do
  if Rails.env.development?
    mount MissionControl::Jobs::Engine, at: "/jobs"
    get "/dev", to: "dev_tools#show", as: :dev_tools
    post "/dev/test_job", to: "dev_tools#test_job", as: :dev_tools_test_job
  end

  resource :session
  resources :passwords, param: :token
  resources :users, only: %i[index edit update]
  resource :profile, only: %i[edit update]
  patch "profile/display_preferences", to: "profiles#update_display_preferences", as: :profile_display_preferences
  scope :admin, as: :admin, module: :admin_area do
    resource :settings, only: %i[show]
    resources :tax_codes
  end

  resources :products, except: [ :show ] do
    resources :product_variants, only: %i[ new create edit update destroy ]
  end
  resources :services, except: [ :show ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root "dashboard#index"
end
