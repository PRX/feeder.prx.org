Rails.application.routes.draw do
  resources :podcasts do
    resource :engagement, only: [:show, :update], controller: :podcast_engagement
    resource :player, only: :show, controller: :podcast_player
    resources :imports, only: [:index, :show, :create]
    resource :planner, only: [:show, :create], controller: :podcast_planner
    resources :feeds, except: [:edit] do
      get "new_apple", on: :collection
    end
    resources :episodes, only: [:index, :create, :new]
    resources :placements_preview, only: [:show]
    get "rollups_demo", to: :rollups_demo
  end

  resources :episodes, except: [:create, :new] do
    resource :media, only: [:show, :update], controller: :episode_media
    get "media_status", to: "episode_media#status"
    resource :player, only: :show, controller: :episode_player
  end

  resource :podcast_switcher, only: [:show, :create], controller: :podcast_switcher
  get "/uploads/signature", to: "uploads#signature", as: :uploads_signature

  mount PrxAuth::Rails::Engine => "/auth", :as => "prx_auth_engine"
  get "sessions/logout", to: "application#logout", as: :logout
  get "sessions/refresh", to: "application#refresh", as: :refresh

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

  get "/.well-known/change-password", to: redirect("https://#{ENV["ID_HOST"]}/.well-known/change-password", status: 302)

  match "/api", via: [:get], to: redirect("/api/v1")
  root "podcasts#index"
end
