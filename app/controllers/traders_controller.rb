class TradersController < ApplicationController
  # respond_to :json

  def index
    @traders        = Trader.all
    @default_trader = Trader.find_by(name: 'default')

    # @chart1a = Charts::OrdersChart.build_chart
    # @chart1b = Charts::ContractsChart.build_chart
    @chart2 = Charts::AccountGrowthChart.build_chart
    @chart3 = Charts::ContractsProfitChart.build_chart
    @chart4 = Charts::OpenContractsChart.build_chart
    @chart5 = Charts::UnresolvedContractsChart.build_chart
    @chart6 = Charts::AccountValueChart.build_chart
    # @chart7 = Charts::MovingAveragesChart.build_chart
    @chart8 = Charts::WeightedAveragesChart.build_chart

    @chart_settings = Charts::GlobalSettings.build

    render :index
  end

  def show
    @order = Order.find(params[:id])
    render :show
  end

  # def create
  #   order = Order.new(params[:type], params[:side], params[:product_id], params[:stp]).submit
  #   render json: order
  # end

  def update
    # @trader = Trader.find(params[:id])
    @trader = Trader.find_by(name: 'default')
    if @trader.update(is_active: params[:is_active])
      Rails.logger.info "updated trader"
      redirect_to :back
    else
      Rails.logger.info "error updating trader"
      # render error
      redirect_to :back
    end
  end

  #=================================================
    private
  #=================================================

    def order_params
      params.require(:order).permit(:status)
    end

end