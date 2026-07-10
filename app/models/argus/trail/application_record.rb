module Argus
  module Trail
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
