Rails.application.routes.draw do
  resources :podcasts, only: [:show], defaults: { format: 'rss' }
  resources :episodes, only: [:show]
  get "/schema", to: "schema#show", defaults: { format: 'json' }
end
