class OrdersController < ApplicationController
  # rescue_from ActiveRecord::RecordNotFound, with: :index
  # respond_to :json

  def index
    render :index
  end

  def show
    @order = Order.find(params[:id])
    render :show
  end

end