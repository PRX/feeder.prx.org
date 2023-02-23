Rails.application.routes.draw do
  # feeder frontend dev
  unless Rails.env.production?
    resources :podcasts do
      resource :engagement, only: [:show, :update], controller: :podcast_engagement
      resource :player, only: :show, controller: :podcast_player
      resources :imports
      resource :planner, only: [:show, :update], controller: :podcast_planner
      resources :feeds, only: [:index]
      resources :episodes, only: [:index, :create, :new]
    end

    resources :episodes, except: [:create, :new]
    resources :feeds
    resource :podcast_switcher, only: [:show, :create], controller: :podcast_switcher
    get "/uploads/signature", to: "uploads#signature", as: :uploads_signature

    resources :fake, only: [:index, :show, :create]

    mount PrxAuth::Rails::Engine => "/auth", :as => "prx_auth_engine"
    get "sessions/logout", to: "application#logout", as: :logout
    get "sessions/refresh", to: "application#refresh", as: :refresh
  end

  namespace :api do
    scope ":api_version", api_version: "v1", defaults: {format: "hal"} do
      resources :podcasts, except: [:new, :edit] do
        resources :episodes, except: [:new, :edit]
        resources :guids, only: :show, controller: :episodes, id: /[^\/]+/, defaults: {guid_resource: true}
      end
      resources :episodes, except: [:new, :edit]
      resources :feeds, only: [:index]

      root to: "base#entrypoint"
      match "*any", via: [:options], to: "base#options"

      resource :authorization, only: [:show] do
        resources :podcasts, except: [:new, :edit], module: :auth do
          resources :episodes, except: [:new, :edit]
          resources :feeds, except: [:new, :edit]
          resources :guids, only: :show, controller: :episodes, id: /[^\/]+/, defaults: {guid_resource: true}
        end

        resources :episodes, except: [:new, :edit], module: :auth
      end
    end
  end

  match "/api", via: [:get], to: redirect("/api/v1")
  match "/", via: [:get], to: redirect("/api/v1")
end
