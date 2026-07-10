module Argus
  module Trail
    class Current < ActiveSupport::CurrentAttributes
      attribute :actor
    end
  end
end
