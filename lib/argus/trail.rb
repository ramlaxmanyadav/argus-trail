require "argus/trail/version"
require "argus/trail/configuration"
require "argus/trail/current"
require "argus/trail/actor"
require "argus/trail/authorizable"
require "argus/trail/permission_scanner"
require "argus/trail/pagination"
require "argus/trail/engine"

module Argus
  module Trail
    EVENT_TYPES = %w[role_assigned role_revoked permission_granted permission_revoked].freeze

    class << self
      def configure
        yield config
      end

      def config
        @config ||= Configuration.new
      end

      def current_actor=(actor)
        Current.actor = actor
      end

      def current_actor
        Current.actor
      end
    end
  end
end
