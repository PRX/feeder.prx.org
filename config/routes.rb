Rails.application.routes.draw do
  resources :podcasts, only: [:show], defaults: {format: "rss"}
  resources :feeds, only: [:index]

  # feeder frontend dev
  unless Rails.env.production?
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
