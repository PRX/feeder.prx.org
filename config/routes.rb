Rails.application.routes.draw do
  namespace :api do
    scope ':api_version', api_version: 'v1', defaults: { format: 'hal' } do
      resources :podcasts, only: [:show, :index] do
        resources :episodes, only: [:show, :index]
      end
      resources :episodes, only: [:show, :index]

      root to: 'base#entrypoint'
      match '*any', via: [:options], to: 'base#options'
    end
  end

  match '/api', via: [:get], to: redirect("/api/v1")
  match '/', via: [:get], to: redirect("/api/v1")

  resources :podcasts, only: [:show], defaults: { format: 'rss' }
  resources :episodes, only: [:show]
end
