Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  devise_for :users
  devise_scope :user do
    get 'sign_in', to:'users/sessions#new'
    post 'sign_in', to:'users/sessions#create'
    get 'sign_up', to:'users/registrations#new'
    post 'sign_up', to:'users/registrations#create'
    get 'sign_out',to:'users/sessions#destroy'
    get 'forgot_password',to:'users/passwords#new'
    post 'forgot_password',to:'users/passwords#create'
    get 'reset_password',to:'users/passwords#edit'
    put 'reset_password',to:'users/passwords#update'
  end
  root 'welcome#index'

  namespace :blocks do
    get '/', to:'dashboard#index', as: :ticker
    get 'pending_orders', to: 'dashboard#pending', as: :pending
    resources :chains do
      resources :tickers
    end
    resources :points do
      member do
        get 'change_state'
        get 'change_frequency'
      end
    end
    resources :orders do
      collection do
        get 'cancel'
      end
    end
    resources :balances do
      collection do
        get 'sync'
      end
      member do
        get 'all_out'
      end
    end
  end

  namespace :api do
    get 'hit_tickers', to:'quotes#hit_tickers'
    get 'hit_markets', to:'quotes#hit_markets'
    get 'hit_clear_open_orders', to:'quotes#hit_clear_open_orders'
    get 'hit_clear_orders', to:'quotes#hit_clear_business_orders'
    resources :stocks do
      collection do
        get 'quote'
        get 'init'
        get 'balance'
        get 'buy'
        get 'sell'
      end
    end
    resources :wechats do
      collection do
        get 'auth'
      end
    end
  end

end
