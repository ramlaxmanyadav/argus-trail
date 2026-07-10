module Argus
  module Trail
    class PermissionsController < ApplicationController
      before_action :set_permission, only: [ :show, :edit, :update, :destroy ]

      def index
        authorize_access!(Permission)
        @permissions = authorized_scope(Permission).includes(:roles).order(:name)
      end

      def show
      end

      def new
        @permission = Permission.new
        authorize_access!(@permission)
      end

      def create
        @permission = Permission.new(permission_params)
        authorize_access!(@permission)

        if @permission.save
          redirect_to permission_path(@permission), notice: "Permission '#{@permission.name}' created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @permission.update(permission_params)
          redirect_to permission_path(@permission), notice: "Permission '#{@permission.name}' updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @permission.roles.any?
          redirect_to permissions_path,
                      alert: "Cannot delete permission '#{@permission.name}' — it is assigned to #{@permission.roles.count} role(s)."
        else
          @permission.destroy
          redirect_to permissions_path, notice: "Permission '#{@permission.name}' deleted."
        end
      end

      private

      def set_permission
        @permission = Permission.find(params[:id])
        authorize_access!(@permission)
      end

      def permission_params
        params.require(:permission).permit(:name, :description)
      end
    end
  end
end
