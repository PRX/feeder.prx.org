Rails.application.routes.draw do
  prx_auth_routes

  namespace :admin do
    resources :podcasts
    resources :episodes
    root to: "podcasts#index"
  end

  resources :podcasts do
    resource :engagement, only: [:show, :update], controller: :podcast_engagement
    resource :player, only: :show, controller: :podcast_player
    resources :imports, only: [:index, :show, :create]
    resource :planner, only: [:show, :create], controller: :podcast_planner
    resources :feeds, except: [:edit] do
      get "new_apple", on: :collection
      get "new_megaphone", on: :collection
    end
    resources :episodes, only: [:index, :create, :new] do
      get "export", on: :collection
    end
    resources :placements_preview, only: [:show]
    get "rollups_demo", to: "podcasts#rollups_demo"
    resource :metrics, only: [:show], controller: :podcast_metrics do
      get "downloads"
      get "uniques"
      get "episodes"
      get "dropdays"
      get "agents"
    end
  end

  resources :episodes, except: [:create, :new] do
    get "overview"
    resource :media, only: [:show, :update], controller: :episode_media
    get "media_status", to: "episode_media#status"
    resource :player, only: :show, controller: :episode_player
    resource :transcripts, only: [:show, :update], controller: :episode_transcripts
    resource :metrics, only: [:show], controller: :episode_metrics do
      get "downloads"
      get "geos"
      get "agents"
    end
  end

  resource :podcast_switcher, only: [:show, :create], controller: :podcast_switcher
  get "/uploads/signature", to: "uploads#signature", as: :uploads_signature

  namespace :api do
    scope ":api_version", api_version: "v1", defaults: {format: "hal"} do
      resources :podcasts, except: [:new, :edit] do
        resources :episodes, except: [:new, :edit]
        resources :guids, only: :show, controller: :episodes, id: /[^\/]+/, defaults: {guid_resource: true}
      end
      resources :episodes, except: [:new, :edit]
      resources :feeds, only: [:index]

      get "comatose/series/:series_id", to: "podcasts#show"
      get "comatose/stories/:story_id", to: "episodes#show"

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

  unless Rails.configuration.consider_all_requests_local
    match "*unmatched", via: :all, to: "errors#not_found"
  end
end
