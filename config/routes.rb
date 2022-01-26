Rails.application.routes.draw do
  resources :podcasts, only: [:show], defaults: { format: 'rss' }
  resources :feeds, only: [:index]

  namespace :api do
    scope ':api_version', api_version: 'v1', defaults: { format: 'hal' } do
      resources :podcasts, except: [:new, :edit] do
        resources :episodes, except: [:new, :edit]
      end
      resources :episodes, except: [:new, :edit]

      root to: 'base#entrypoint'
      match '*any', via: [:options], to: 'base#options'

      resource :authorization, only: [:show] do
        resources :podcasts, except: [:new, :edit], module: :auth do
          resources :episodes, except: [:new, :edit]
        end

        resources :episodes, except: [:new, :edit], module: :auth
      end
    end
  end

  match '/api', via: [:get], to: redirect('/api/v1')
  match '/', via: [:get], to: redirect('/api/v1')
end
