class UserDashboardsController < ApplicationController
  wrap_parameters :dashboard_config

  def show
    authorize! :update, user

    present DashboardConfig.new(user)
  end

  def create
    authorize! :update, user

    modules = params[:dashboard_config][:modules]
    config = DashboardConfig.new(user)
    config.update(modules)

    present config
  end

  private

  def user
    @user ||= User.find params[:user_id]
  end
end
