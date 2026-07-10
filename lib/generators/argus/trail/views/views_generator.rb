require "rails/generators"

module Argus
  module Trail
    module Generators
      class ViewsGenerator < Rails::Generators::Base
        source_root Argus::Trail::Engine.root.join("app", "views")

        desc "Copies Argus::Trail's views into your app for full override"

        def copy_views
          directory "argus/trail", "app/views/argus/trail"
          directory "layouts/argus/trail", "app/views/layouts/argus/trail"
        end
      end
    end
  end
end
