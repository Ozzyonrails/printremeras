Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # ---- JSON API for the React storefront -------------------------------------
  namespace :api do
    namespace :v1 do
      resource :session, only: %i[show create destroy]
      resource :registration, only: :create
      resources :password_resets, only: :create, param: :token
      patch "password_resets/:token", to: "password_resets#update"
      post "confirmations", to: "confirmations#create"
      patch "confirmations/:token", to: "confirmations#update"
      resource :profile, only: :update
      resource :settings, only: :show

      resources :templates, only: %i[index show], param: :slug
      resources :catalog_items, only: %i[index show], param: :slug do
        post :customize, on: :member
      end
      resources :reviews, only: :index

      resources :uploads, only: :create
      resources :designs, only: %i[index show create destroy] do
        post :validate_placement, on: :collection
      end

      resource :cart, only: :show, controller: :cart do
        post :items, action: :add_item
        patch "items/:id", action: :update_item
        delete "items/:id", action: :remove_item
        post :quote
      end

      resources :addresses, only: %i[index create update destroy]
      resources :coupons, only: [] do
        collection do
          post :validate
          get :mine
        end
      end

      resources :orders, only: %i[index show create], param: :number do
        member do
          post :cancel
          post :payments, to: "payments#create"
          get "payments/status", to: "payments#status"
          post :review, to: "reviews#create"
        end
      end
      resources :messages, only: %i[index create]
    end
  end

  # ---- Payment provider webhooks (public, idempotent) --------------------------
  post "webhooks/:provider", to: "webhooks/payments#create", as: :payment_webhook

  # ---- Google OAuth -----------------------------------------------------------
  get "auth/google_oauth2/callback", to: "identity/omniauth_callbacks#google"
  post "auth/google_oauth2/callback", to: "identity/omniauth_callbacks#google"
  get "auth/failure", to: "identity/omniauth_callbacks#failure"

  # ---- Fake gateway simulator (only when PAYMENTS_GATEWAY=Payments::FakeGateway)
  namespace :dev do
    resources :payments, only: :show do
      post :simulate, on: :member
    end
  end

  # ---- Admin (server-rendered) -------------------------------------------------
  namespace :admin do
    root to: "dashboard#index"
    resource :session, only: %i[new create destroy]
    resource :locale, only: :update, controller: :locales
    resources :orders, only: %i[index show], param: :number do
      member do
        post :transition
        post :refund
        get :artwork
        post :rerender
      end
    end
    resources :moderation, only: %i[index show], param: :number, controller: :moderation do
      member do
        post :approve
        post :reject
      end
    end
    resources :reviews, only: %i[index show update] do
      member do
        post :approve
        post :reject
      end
    end
    resources :coupons, only: %i[index new create update]
    resources :templates do
      resources :print_areas, only: %i[create update destroy]
      resources :template_sizes, only: %i[create update destroy]
    end
    resources :designs, only: %i[create]
    resources :artwork, only: :index, controller: :artwork do
      member do
        post :enhance
        post :dismiss
      end
    end
    resources :catalog_items do
      member do
        get :editor
        post :publish
      end
    end
    resources :customers, only: %i[index show]
    resources :conversations, only: %i[index show] do
      resources :messages, only: :create
    end
    resource :settings, only: %i[show update]
    resources :audit_logs, only: :index
    resources :admin_users, only: %i[index new create edit update]
    mount MissionControl::Jobs::Engine, at: "jobs", as: :jobs
  end

  # ---- SPA catch-all (storefront) ---------------------------------------------
  root "spa#show"
  get "*path", to: "spa#show", constraints: ->(req) { !req.path.start_with?("/rails/", "/admin", "/api/", "/webhooks/", "/dev/", "/auth/", "/cable", "/app/", "/assets/") && !req.path.match?(/\.\w{1,5}\z/) }
end
