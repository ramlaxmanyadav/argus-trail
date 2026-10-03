Rails.application.routes.draw do
  resources :widgets, only: [ :index, :show ]
  mount Argus::Trail::Engine => "/argus-trail"
end
