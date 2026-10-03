class WidgetsController < ApplicationController
  include Argus::Trail::Authorizable

  def index
    head :ok
  end

  def show
    head :ok
  end
end
