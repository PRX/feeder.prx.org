Rails.application.routes.draw do
  resources :podcasts, only: [:show], defaults: { format: 'rss' }
  resources :episodes, only: [:create, :update]
  get "/schema", to: "schema#show", defaults: { format: 'json' }
end
