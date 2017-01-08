class OrdersController < ApplicationController
  # rescue_from ActiveRecord::RecordNotFound, with: :index
  # respond_to :json

  def index
    @orders            = Order.pluck(:id, :type, :price, :status).last(100)
    @current_price     = GDAX::MarketData.last_trade.price
    @sell_orders_count = SellOrder.done.count
    @buy_orders_count  = BuyOrder.done.count
    @open_buys         = BuyOrder.where(status: ['open', 'pending']).count
    @open_sells        = SellOrder.where(status: ['open', 'pending']).count

    @chart1 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Buy and Sell Orders")
      f.xAxis(categories: ["Sell Orders", "Buy Orders"])
      f.series(name: "Completed Orders", yAxis: 0, data: [@sell_orders_count, @buy_orders_count])
      f.series(name: "Open Orders", yAxis: 1, data: [@open_sells, @open_buys])

      f.yAxis [
        {title: {text: "Complete Orders", margin: 70} },
        {title: {text: "Open Orders"}, opposite: true},
      ]

      f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
      f.chart({defaultSeriesType: "column"})
    end

    @unresolved_contracts = Contract.unresolved
    @resolved_contracts_daily = Contract.order("date_trunc('day', updated_at)").group("date_trunc('day', updated_at)")

    @chart2 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Contracts")
      f.xAxis(categories: @resolved_contracts_daily.count.keys)
      f.yAxis(type: "datetime", categories: @resolved_contracts_daily.count.keys)
      f.labels(items: [html:"Contracts Metrics", style: {left: "40px", top: "8px", color: "black"}])
      f.series(type: 'column', name: 'Total Contracts', yAxis: 0, data: @resolved_contracts_daily.count.values)
      f.series(type: 'column', name: 'ROI', yAxis: 1, data: @resolved_contracts_daily.sum(:roi).values.map {|c| c.to_f})
      # f.series(:type=> 'column', :name=> 'John',:data=> [2, 3, 5, 7, 6])
      # f.series(:type=> 'column', :name=> 'Joe',:data=> [4, 3, 3, 9, 0])

      f.yAxis [
        {title: {text: "Total Contracts", margin: 70} },
        {title: {text: "ROI"}, opposite: true},
      ]

      f.series(type: 'spline', name: 'Resolved Contracts', data: @resolved_contracts_daily.count.to_a)

      f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
      # f.chart({defaultSeriesType: "column"})
    end

    @resolved_contracts_hourly = Contract.order("date_trunc('hour', updated_at)").group("date_trunc('hour', updated_at)")

    @chart3 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Contracts Profit")
      f.xAxis(categories: @resolved_contracts_hourly.count.keys)
      f.yAxis(type: "datetime", categories: @resolved_contracts_hourly.count.keys)
      # f.labels(items: [html:"Contracts Metrics", style: {left: "40px", top: "8px", color: "black"}])
      # f.series(type: 'column', name: 'Total Contracts', yAxis: 0, data: @resolved_contracts_hourly.count.values)
      f.series(type: 'column', name: 'ROI', yAxis: 1, data: @resolved_contracts_hourly.sum(:roi).values.map {|c| c.to_f})
      # f.series(:type=> 'column', :name=> 'John',:data=> [2, 3, 5, 7, 6])
      # f.series(:type=> 'column', :name=> 'Joe',:data=> [4, 3, 3, 9, 0])

      f.yAxis [
        {title: {text: "Total Contracts", margin: 70} },
        {title: {text: "ROI"}, opposite: true},
      ]

      # f.series(type: 'spline', name: 'Resolved Contracts', data: @resolved_contracts_hourly.count.to_a)

      f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
      # f.chart({defaultSeriesType: "column"})
    end

    @chart_globals = LazyHighCharts::HighChartGlobals.new do |f|
      f.global(useUTC: false)
      f.chart(
        backgroundColor: {
          linearGradient: [0, 0, 500, 500],
          stops: [
            [0, "rgb(255, 255, 255)"],
            [1, "rgb(240, 240, 255)"]
          ]
        },
        borderWidth: 2,
        plotBackgroundColor: "rgba(255, 255, 255, .9)",
        plotShadow: true,
        plotBorderWidth: 1
      )
      f.lang(thousandsSep: ",")
      f.colors(["#90ed7d", "#f7a35c", "#8085e9", "#f15c80", "#e4d354"])
    end

    render :index
  end

  def show
    @order = Order.find(params[:id])
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