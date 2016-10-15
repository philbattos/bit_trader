class OrdersController < ApplicationController
  # rescue_from ActiveRecord::RecordNotFound, with: :index
  # respond_to :json

  def index
    @orders = Order.fetch_all
    @current_price = Market.last_trade.price
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

  def update
    @order = Order.find_by_gdax_id(params[:id])
    if @order && @order.update(order_params)
      # OrderWorker.send_cancel_request
      render :update
    else
      render json: { errors: 'Order not found' }, status: 422
    end
  end

  #=================================================
    private
  #=================================================

    def order_params
      params.require(:order).permit(:status)
    end

end