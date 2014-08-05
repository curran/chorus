class DashboardsController < ApplicationController

  def show
    dashboard = Dashboard.build(params[:entity_type]).fetch!

    present dashboard, :presenter_options => { :presenter_class => Dashboard::BasePresenter }
  end
end
