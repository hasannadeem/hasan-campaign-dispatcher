require "sidekiq/web"

Rails.application.routes.draw do
  resources :campaigns, only: %i[index show create] do
    collection do
      get :import
      post :import
    end
    member do
      post :start
      post :retry_failed
    end
  end

  mount Sidekiq::Web => "/sidekiq"

  get "up" => "rails/health#show", as: :rails_health_check

  root "campaigns#index"
end
