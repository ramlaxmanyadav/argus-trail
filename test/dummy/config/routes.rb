Rails.application.routes.draw do
  mount Argus::Trail::Engine => "/argus-trail"
end
