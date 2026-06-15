require "sidekiq/web"

Rails.application.routes.draw do
  resources :campaigns, only: %i[index show create] do
    post :start, on: :member
  end

  mount Sidekiq::Web => "/sidekiq"

  get "up" => "rails/health#show", as: :rails_health_check

  root "campaigns#index"
end
