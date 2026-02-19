Rails.application.routes.draw do
  # Mount Action Cable server for WebSocket connections
  mount ActionCable.server => "/cable"

  if Rails.env.development?
    mount MissionControl::Jobs::Engine, at: "/jobs"
    get "/dev", to: "dev_tools#show", as: :dev_tools
    post "/dev/test_job", to: "dev_tools#test_job", as: :dev_tools_test_job
    post "/dev/reindex_search", to: "dev_tools#reindex_search", as: :dev_tools_reindex_search
  end

  get "search", to: "search#index", as: :search
  get "search/product_results", to: "search#product_results", as: :product_results_search
  get "filters/chip", to: "filters#chip", as: :filter_chip

  resource :session
  resources :passwords, param: :token
  resource :profile, only: %i[edit update]
  patch "profile/display_preferences", to: "profiles#update_display_preferences", as: :profile_display_preferences
  scope :admin, as: :admin, module: :admin_area do
    resource :settings, only: %i[show]
    resource :store, only: %i[show update], controller: "store"
    resource :data_export, only: %i[show create]
    resources :imports, only: %i[new create show] do
      member do
        patch :execute
      end
    end
    resource :shopify, only: %i[show], controller: "shopify" do
      post :sync_all, on: :member
      post :test_connection, on: :member
    end
    resource :backups, only: %i[ show ] do
      get :download, on: :member
      get :authorize, on: :member
      get :oauth_callback, on: :member
      delete :disconnect, on: :member
    end
    resources :users, only: %i[index show new create edit update]
    resources :tax_codes
    resources :suppliers
    resources :audits, only: %i[index show], path: "audits"
    resources :receipt_templates do
      member do
        patch :activate
        get :preview
      end
    end
    resources :discounts do
      member do
        patch :toggle_active
        get :search_items
        post :bulk_add_items
      end
      resources :discount_items, only: %i[create destroy], shallow: true
    end
    resources :gift_certificates, only: %i[index show]
  end

  resources :notifications, only: [ :index, :destroy ] do
    collection do
      patch :mark_all_read
      delete :clear_all
    end
    member { patch :mark_read }
  end
  resources :push_subscriptions, only: [ :create, :destroy ]
  resources :saved_queries, only: %i[create destroy]

  resource :register, only: [ :show ], controller: "register" do
    post :new_order, on: :member
  end

  resource :cash_drawer, only: [ :show ], controller: "cash_drawer" do
    get :open, action: :new_open
    post :open, action: :create_open
    get :close, action: :new_close
    post :close, action: :create_close
    get :reconcile, action: :new_reconcile
    post :reconcile, action: :create_reconcile
    get :history
    get "history/:id", action: :session_detail, as: :session_detail
  end

  resources :reports, only: %i[index new create show destroy] do
    member do
      get :export_pdf
      get :export_excel
    end
  end
  get "gift_certificates/lookup", to: "gift_certificates#lookup", as: :gift_certificate_lookup

  resources :orders do
    resources :gift_certificates, only: %i[new create]
    resources :order_lines, only: %i[create update destroy], shallow: true
    resources :order_payments, only: %i[create destroy], shallow: true
    resources :order_discounts, only: %i[create destroy], shallow: true
    resources :order_discount_overrides, only: %i[destroy]
    resources :order_line_discounts, only: [], shallow: true do
      member do
        patch :exclude
        patch :restore
      end
    end
    member do
      post :hold
      post :resume
      post :complete
      delete :cancel
      patch :assign_customer
      delete :remove_customer
      get :receipt
      get :refund_form
      post :process_refund
    end
    collection do
      get :held
      post :quick_lookup
    end
  end

  resources :products do
    member do
      delete :purge_image
      get :preview
    end
  end
  resources :services do
    member do
      get :preview
    end
  end
  resources :customers do
    collection do
      get :search
    end
  end
  resources :store_tasks
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
