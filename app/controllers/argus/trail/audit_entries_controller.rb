module Argus
  module Trail
    class AuditEntriesController < ApplicationController
      def index
        authorize_access!(AuditEntry)

        @entries = authorized_scope(AuditEntry)
                     .includes(:subject, :changed_by, :role, :from_role, :permission)
                     .recent

        @entries = @entries.where(subject_type: params[:subject_type]) if params[:subject_type].present?
        @entries = @entries.where(subject_id: params[:subject_id]) if params[:subject_id].present?
        @entries = @entries.where(role_id: params[:role_id]) if params[:role_id].present?

        @pages = Argus::Trail::Pagination.paginate(@entries, page: params[:page], per: Argus::Trail.config.per_page)
      end
    end
  end
end
