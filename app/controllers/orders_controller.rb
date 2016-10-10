class OrdersController < ApplicationController
  # respond_to :json

  def index
    @orders = Order.fetch_all
    @ticker = Order.fetch_ticker
    @current_price = JSON.parse(@ticker.body)['price']
    render :index
  end

  def show
    @order = Order.fetch_single(params[:id])
    render :show
  end

  def create
    order = Order.new(params[:type], params[:side], params[:product_id], params[:stp]).submit
    render json: order
  end

end