module Argus
  module Trail
    module Pagination
      # Minimal stand-in for a Kaminari page, used only when the host app
      # hasn't bundled Kaminari. Implements just enough of Kaminari's relation
      # interface for the engine's views (current_page, total_pages, total_count, each).
      class SimplePage
        include Enumerable

        attr_reader :current_page, :per_page, :total_count

        def initialize(relation, page:, per:)
          @current_page = [ page.to_i, 1 ].max
          @per_page     = per
          @total_count  = relation.count
          @records      = relation.offset((@current_page - 1) * per).limit(per).to_a
        end

        def each(&block) = @records.each(&block)
        def any? = @records.any?
        def empty? = @records.empty?
        def size = @records.size

        def total_pages
          return 0 if per_page.zero?
          (total_count.to_f / per_page).ceil
        end
      end

      module_function

      def paginate(relation, page:, per:)
        if defined?(Kaminari)
          relation.page(page).per(per)
        else
          SimplePage.new(relation, page: page, per: per)
        end
      end
    end
  end
end
