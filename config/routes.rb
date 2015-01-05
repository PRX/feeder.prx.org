Rails.application.routes.draw do
  resources :podcasts, only: [:show], defaults: { format: 'rss' }
  resources :episodes, only: [:create]
end
