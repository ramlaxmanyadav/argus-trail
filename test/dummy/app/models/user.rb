class User < ApplicationRecord
  include Argus::Trail::Actor

  def argus_trail_display_name
    name.presence || email
  end
end
