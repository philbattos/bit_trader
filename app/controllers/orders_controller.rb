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
    @resolved_contracts_daily = Contract.resolved.order("date_trunc('day', updated_at)").group("date_trunc('day', updated_at)")

    @chart2 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Contracts")
      f.xAxis(categories: @resolved_contracts_daily.count.keys.map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%-m/%d").strip })
      f.yAxis(type: "datetime", categories: @resolved_contracts_daily.count.keys.map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%-m/%y").strip })
      f.labels(items: [html:"Contracts (Daily)", style: {left: "40px", top: "8px", color: "black"}])
      f.series(type: 'column', name: 'Total Contracts', yAxis: 0, data: @resolved_contracts_daily.count.values)
      f.series(type: 'column', name: 'ROI', yAxis: 1, data: @resolved_contracts_daily.sum(:roi).values.map(&:to_f))
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

    @resolved_contracts_hourly = Contract.resolved.order("date_trunc('hour', updated_at)").group("date_trunc('hour', updated_at)")

    @chart3 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Contracts Profit")
      f.xAxis(categories: @resolved_contracts_hourly.count.keys.last(30).map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%l%P").strip })
      f.yAxis(type: "datetime", categories: @resolved_contracts_hourly.count.keys.last(30).map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip })
      f.labels(items: [html:"Contracts (Hourly)", style: {left: "40px", top: "8px", color: "black"}])
      f.series(type: 'column', name: 'Completed Contracts', yAxis: 0, data: @resolved_contracts_hourly.count.values.last(30))
      f.series(type: 'column', name: 'ROI', yAxis: 1, data: @resolved_contracts_hourly.sum(:roi).values.last(30).map(&:to_f))
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

    @unresolved_contracts = Contract.unresolved
    @completed_buys       = @unresolved_contracts.joins(:buy_orders).where(orders: {status: 'done'}).order(:created_at)
    @completed_sells      = @unresolved_contracts.joins(:sell_orders).where(orders: {status: 'done'}).order(:created_at)

    @chart4 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Open Contracts")

      # f.labels(
      #   items: [
      #     html:"Unresolved Contracts",
      #     style: {
      #       left: "40px",
      #       top: "8px",
      #       color: "black"
      #     }
      #   ]
      # )

      f.xAxis(
        title: { text: "Date", margin: 30 },
        type: "datetime",
        # tickPositions: @unresolved_contracts.order("date_trunc('day', created_at)").map {|c| c.created_at.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip }.uniq
        # categories: @unresolved_contracts.order("date_trunc('day', created_at)").map {|c| c.created_at.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip }.uniq
      )

      f.yAxis(
        title: { text: "Price", margin: 20 },
        type: "linear"
      )

      f.series(
        type: 'scatter',
        name: 'Completed Buy',
        color: 'rgba(119, 152, 191, .5)',
        data: @completed_buys.pluck("contracts.created_at, orders.price").map {|c| [c.first.to_i, c.last.to_f] }
      )

      f.series(
        type: 'scatter',
        name: 'Completed Sell',
        color: 'rgba(223, 83, 83, .5)',
        data: @completed_sells.pluck("contracts.created_at, orders.price").map {|c| [c.first.to_i, c.last.to_f] }
        # pointStart: @unresolved_contracts.order(:created_at).first
      )

      f.plotOptions(
        scatter: {
          marker: {},
          states: {},
          series: {
            pointStart: @unresolved_contracts.order(:created_at).first.created_at,
            pointInterval: 24 * 3600 * 1000 # one day
          },
          tooltip: {
            headerFormat: '<b>{series.name}</b><br>',
            pointFormat: '{point.x}, {point.y}'
            # pointFormat: '{Time.at(point.x).in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d %l:%M%P").strip}, {point.y}'
          }
        }
      )

      f.legend(
        align: 'right',
        verticalAlign: 'top',
        y: 75,
        x: -50,
        layout: 'vertical',
        floating: true
      )
    end

    @unresolved_countracts_hourly = 70.downto(0).map do |x|
      time = x.hours.ago
      contracts_at_time = Contract.where("created_at < ?", time).distinct.count
      completed_at_time = Contract.resolved.where("completion_date < ?", time).distinct.count
      [time.to_i * 1000, contracts_at_time - completed_at_time]
    end

    @chart5 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Unresolved Contracts")
      f.chart(zoomType: 'x')
      f.subtitle(text: "Contracts Without A Completed Buy & Sell")

      f.xAxis(
        type: 'datetime',
        # tickInterval: 3600 * 1000,
        # min: 4.days.ago.to_i * 1000,
        # max: Time.now.to_i * 1000
      )

      f.yAxis(
        title: { text: "Contracts", margin: 70 },
        plotLines: [{
          value: 0,
          width: 1,
          color: '#808080'
        }]
      )

      f.series(
        # type: 'spline',
        type: 'area',
        name: 'Open Contracts',
        data: @unresolved_countracts_hourly,
        # pointStart: 2.weeks.ago.to_i,
        # pointInterval: 24 * 3600 * 1000, # one day
        # pointRange: 24 * 3600 * 1000 # one day
      )

      f.legend(
        layout: 'vertical',
        align: 'right',
        verticalAlign: 'top',
        y: 75,
        x: -50,
        floating: true
      )
    end

    @chart_globals = LazyHighCharts::HighChartGlobals.new do |f|
      # NOTE: for high-charts times, use milliseconds:
      #       find the Rails date/time, convert to epoch time with .to_i, and then multiply by 1000
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