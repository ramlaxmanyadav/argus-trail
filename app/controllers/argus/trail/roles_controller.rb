module Argus
  module Trail
    class RolesController < ApplicationController
      before_action :set_role, only: [ :show, :edit, :update, :destroy ]
      before_action :set_permissions, only: [ :new, :edit, :create, :update ]

      def index
        authorize_access!(Role)
        @roles = authorized_scope(Role).includes(:permissions).order(:name)
      end

      def show
      end

      def new
        @role = Role.new
        authorize_access!(@role)
      end

      def create
        @role = Role.new(role_params)
        authorize_access!(@role)

        if @role.save
          @role.sync_permissions!(params[:permission_ids], changed_by: current_actor)
          redirect_to role_path(@role), notice: "Role '#{@role.name}' created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @role.update(role_params)
          @role.sync_permissions!(params[:permission_ids], changed_by: current_actor)
          redirect_to role_path(@role), notice: "Role '#{@role.name}' updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @role.actors.any?
          redirect_to roles_path,
                      alert: "Cannot delete role '#{@role.name}' — it is assigned to #{@role.actors.count} record(s)."
        else
          @role.destroy
          redirect_to roles_path, notice: "Role '#{@role.name}' deleted."
        end
      end

      private

      def set_role
        @role = Role.find(params[:id])
        authorize_access!(@role)
      end

      def set_permissions
        @permissions = Permission.order(:name)
      end

      def role_params
        params.require(:role).permit(:name, :description)
      end
    end
  end
end
