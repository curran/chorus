class VisualizationsController < ApplicationController
  include DataSourceAuth

  wrap_parameters :chart_task

  def create
    dataset = Dataset.find(params[:dataset_id])
    visualization = Visualization.build(dataset, params[:chart_task])
    visualization.fetch!(authorized_account(dataset), params[:chart_task][:check_id])
    present visualization
  end

  def destroy
    dataset = Dataset.find(params[:dataset_id])
    authorized_account(dataset)
    CancelableQuery.cancel(params[:id], current_user)
    head :ok
  end
end
