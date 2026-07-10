Argus::Trail::Engine.routes.draw do
  resources :roles
  resources :permissions
  resources :audit_entries, only: [ :index ]

  root to: "roles#index"
end
