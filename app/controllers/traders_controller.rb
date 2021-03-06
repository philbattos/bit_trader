class TradersController < ApplicationController
  # respond_to :json

  def index
    @traders        = Trader.all
    @default_trader = Trader.find_by(name: 'default')

    @trendline_profit_all_count = Contract.trendline.resolved.count
    @trendline_profit_all_value = Contract.trendline.resolved.sum(:roi)
    @trendline_profit_all_percent = (@trendline_profit_all_value / @trendline_profit_all_count)

    contracts_from_last_month = Contract.trendline.resolved.where("created_at > ?", 30.days.ago)
    @trendline_profit_month_count = contracts_from_last_month.count
    @trendline_profit_month_value = contracts_from_last_month.sum(:roi)
    @trendline_profit_month_percent = (@trendline_profit_month_value / @trendline_profit_month_count)

    contracts_from_last_week = Contract.trendline.resolved.where("created_at > ?", 7.days.ago)
    @trendline_profit_week_count = contracts_from_last_week.count
    @trendline_profit_week_value = contracts_from_last_week.sum(:roi)
    @trendline_profit_week_percent = (@trendline_profit_week_value / @trendline_profit_week_count)

    @ema_750_2500_profit_all_count = Contract.ema_cross_750_2500_min.resolved.count
    @ema_750_2500_profit_all_value = Contract.ema_cross_750_2500_min.resolved.sum(:roi)
    @ema_750_2500_profit_all_percent = (@ema_750_2500_profit_all_value / @ema_750_2500_profit_all_count)

    ema_contracts_from_last_month = Contract.ema_cross_750_2500_min.resolved.where("created_at > ?", 30.days.ago)
    @ema_750_2500_profit_month_count = ema_contracts_from_last_month.count
    @ema_750_2500_profit_month_value = ema_contracts_from_last_month.sum(:roi)
    @ema_750_2500_profit_month_percent = (@ema_750_2500_profit_month_value / @ema_750_2500_profit_month_count)

    ema_contracts_from_last_week = Contract.ema_cross_750_2500_min.resolved.where("created_at > ?", 7.days.ago)
    @ema_750_2500_profit_week_count = ema_contracts_from_last_week.count
    @ema_750_2500_profit_week_value = ema_contracts_from_last_week.sum(:roi)
    @ema_750_2500_profit_week_percent = (@ema_750_2500_profit_week_value / @ema_750_2500_profit_week_count)

    @ema_750_2500_profit_per_btc_unit = (@ema_750_2500_profit_all_percent * 0.667)

    # @chart1a = Charts::OrdersChart.build_chart
    # @chart1b = Charts::ContractsChart.build_chart
    # @chart4 = Charts::OpenContractsChart.build_chart
    # @chart5 = Charts::UnresolvedContractsChart.build_chart
    # @chart6 = Charts::AccountValueChart.build_chart
    # @chart7 = Charts::MovingAveragesChart.build_chart
    @chart8 = Charts::WeightedAveragesChart.build_chart
    @chart9 = Charts::TrendlineContractsChart.build_chart
    @chart10 = Charts::TrendlineROIChart.build_chart
    @chart3 = Charts::ContractsProfitChart.build_chart
    @chart2 = Charts::AccountGrowthChart.build_chart

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