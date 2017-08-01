Rails.application.routes.draw do

  resources :orders
  resources :transfers
  resources :accounts
  resources :traders, only: :update

end
