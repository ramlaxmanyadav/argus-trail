module Argus
  module Trail
    module ApplicationHelper
      BADGE_PALETTE = [
        "bg-red-100 text-red-800",
        "bg-yellow-100 text-yellow-800",
        "bg-green-100 text-green-800",
        "bg-blue-100 text-blue-800",
        "bg-purple-100 text-purple-800",
        "bg-pink-100 text-pink-800",
        "bg-indigo-100 text-indigo-800"
      ].freeze

      # Deterministic name -> palette mapping so any role name gets a stable
      # badge color, without a hardcoded admin/manager/bde case statement.
      def role_badge_class(name)
        return "bg-gray-100 text-gray-700" if name.blank?
        BADGE_PALETTE[name.to_s.sum % BADGE_PALETTE.size]
      end

      def event_type_label(event_type)
        event_type.to_s.humanize
      end

      def argus_trail_paginate(pages)
        if pages.is_a?(Argus::Trail::Pagination::SimplePage)
          render partial: "argus/trail/pagination/simple_pager", locals: { pages: pages }
        else
          paginate(pages)
        end
      end
    end
  end
end
