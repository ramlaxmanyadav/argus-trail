module Argus
  module Trail
    class Engine < ::Rails::Engine
      isolate_namespace Argus::Trail

      config.generators do |g|
        g.test_framework false
        g.assets false
        g.helper false
      end
    end
  end
end
