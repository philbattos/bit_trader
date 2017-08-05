class TradersController < ApplicationController
  # respond_to :json

  def index
    @traders        = Trader.all
    @default_trader = Trader.find_by(name: 'default')
    # @orders            = Order.pluck(:id, :type, :price, :status).last(100)
    # @current_price     = GDAX::MarketData.last_trade.price
    # @sell_orders_count = SellOrder.done.count
    # @buy_orders_count  = BuyOrder.done.count
    # @open_buys         = BuyOrder.where(status: ['open', 'pending']).count
    # @open_sells        = SellOrder.where(status: ['open', 'pending']).count

    # @chart1 = LazyHighCharts::HighChart.new('graph') do |f|
    #   f.title(text: "Buy and Sell Orders")
    #   f.xAxis(categories: ["Sell Orders", "Buy Orders"])
    #   f.series(name: "Completed Orders", yAxis: 0, data: [@sell_orders_count, @buy_orders_count])
    #   f.series(name: "Open Orders", yAxis: 1, data: [@open_sells, @open_buys])

    #   f.yAxis [
    #     {title: {text: "Complete Orders", margin: 70} },
    #     {title: {text: "Open Orders"}, opposite: true},
    #   ]

    #   f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
    #   f.chart({defaultSeriesType: "column"})
    # end

    # @unresolved_contracts = Contract.unresolved
    # @resolved_contracts_daily = Contract.resolved.order("date_trunc('day', updated_at)").group("date_trunc('day', updated_at)")

    # @chart2 = LazyHighCharts::HighChart.new('graph') do |f|
    #   f.title(text: "Contracts")
    #   f.xAxis(categories: @resolved_contracts_daily.count.keys.map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%-m/%d").strip })
    #   f.yAxis(type: "datetime", categories: @resolved_contracts_daily.count.keys.map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%-m/%y").strip })
    #   f.labels(items: [html:"Contracts (Daily)", style: {left: "40px", top: "8px", color: "black"}])
    #   f.series(type: 'column', name: 'Total Contracts', yAxis: 0, data: @resolved_contracts_daily.count.values)
    #   f.series(type: 'column', name: 'ROI', yAxis: 1, data: @resolved_contracts_daily.sum(:roi).values.map(&:to_f))
    #   # f.series(:type=> 'column', :name=> 'John',:data=> [2, 3, 5, 7, 6])
    #   # f.series(:type=> 'column', :name=> 'Joe',:data=> [4, 3, 3, 9, 0])

    #   f.yAxis [
    #     {title: {text: "Total Contracts", margin: 70} },
    #     {title: {text: "ROI"}, opposite: true},
    #   ]

    #   f.series(type: 'spline', name: 'Resolved Contracts', data: @resolved_contracts_daily.count.to_a)

    #   f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
    #   # f.chart({defaultSeriesType: "column"})
    # end

    @chart2 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Account Growth")
      f.chart(zoomType: 'x')

      f.xAxis(
        type: 'datetime',
        plotLines: [{
          value: 1493535618000, # April 30, 1:00am
          width: 1,
          color: 'red',
          dashStyle: 'dot',
          label: {
            text: "Started new algorithm: logarithmic spread",
            style: { color: 'lightgray' }
          }
        }]
      )

      f.yAxis([
        { title: { text: "Bitcoin Price" }},
        {
          title: { text: "Account Value" },
          opposite: true
        }
      ])

      f.series(
        name: 'Bitcoin Price',
        data: Metric.order(:id).pluck(:created_at, :bitcoin_price).last(1000).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        name: 'Account Value',
        data: Metric.order(:id).pluck(:created_at, :account_value).last(1000).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 1
      )

      f.plotOptions(
        series: {
          marker: { enabled: false },
          lineWidth: 1
        }
      )

      f.tooltip(
        valuePrefix: '$'
      )

      f.legend(
        layout: 'vertical',
        align: 'left',
        verticalAlign: 'top',
        floating: true
      )
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
    @current_price        = (GDAX::MarketData.last_saved_trade.price * 0.01).to_f

    @chart4 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Open Contracts")

      f.xAxis(
        # title: { text: "Price" },
        # type: "linear",
        # tickPositions: @unresolved_contracts.order("date_trunc('day', created_at)").map {|c| c.created_at.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip }.uniq
        # categories: @unresolved_contracts.order("date_trunc('day', created_at)").map {|c| c.created_at.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip }.uniq
        plotLines: [{
          value: @current_price,
          width: 1,
          color: 'red',
          dashStyle: 'dot',
          label: {
            text: "Current Price $#{@current_price}",
            style: { color: 'lightgray' }
          }
        }]
      )

      f.yAxis(
        type: "datetime",
        title: { text: "Date", margin: 20 }
      )

      f.series(
        type: 'scatter',
        name: 'Completed Buy',
        color: 'rgba(119, 152, 191, .5)',
        data: @completed_buys.pluck("orders.executed_value, (EXTRACT(EPOCH FROM orders.created_at) * 1000)").map {|o| [o.first.to_f, o.last] }
      )

      f.series(
        type: 'scatter',
        name: 'Completed Sell',
        color: 'rgba(223, 83, 83, .5)',
        data: @completed_sells.pluck("orders.executed_value, (EXTRACT(EPOCH FROM orders.created_at) * 1000)").map {|o| [o.first.to_f, o.last] }
        # pointStart: @unresolved_contracts.order(:created_at).first
      )

      f.plotOptions(
        scatter: {
          marker: {},
          states: {},
          series: {
            pointStart: @unresolved_contracts.any? ? @unresolved_contracts.order(:created_at).first.try(:created_at) : 0,
            pointInterval: 24 * 3600 * 1000 # one day
          },
          # tooltip: {
          #   # borderWidth: 3,
          #   headerFormat: '<b>{series.name}</b><br>',
          #   pointFormat: '${point.x}, {point.y}'
          #   # pointFormat: '{Time.at(point.x).in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d %l:%M%P").strip}, {point.y}'
          # }
        }
      )

      f.tooltip(
        borderWidth: 3
      )

      f.legend(
        align: 'right',
        verticalAlign: 'top',
        layout: 'vertical',
        y: 75,
        x: -50
        # floating: true
      )
    end

    recent_metrics        = Metric.order("id desc").limit(350) # 2+ days of metrics
    @incomplete_contracts = recent_metrics.pluck(:created_at, :unresolved_contracts).map {|m| [m.first.to_i * 1000, m.last]}
    # @active_orders        = recent_metrics.pluck(:created_at, :open_orders).map {|m| [m.first.to_i * 1000, m.last]}

    @chart5 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Unresolved Contracts")
      f.subtitle(text: "Contracts Without A Completed Buy & Sell")
      f.chart(zoomType: 'x')

      f.xAxis(
        type: 'datetime'
      )

      f.yAxis(
        title: { text: "Contracts", margin: 20 },
        # plotLines: [{
        #   value: 0,
        #   width: 1,
        #   color: '#434b8e'
        # }]
      )

      f.series(
        # type: 'spline',
        name: 'Open Contracts',
        data: @incomplete_contracts,
        yAxis: 0
      )

      # f.series(
      #   type: 'column',
      #   name: 'Active Orders',
      #   data: @active_orders
      # )

      f.plotOptions(
        series: {
          marker: { enabled: false },
          lineWidth: 1
        }
      )

      # f.legend(
      #   layout: 'vertical',
      #   align: 'right',
      #   verticalAlign: 'top',
      #   y: 75,
      #   x: -50,
      #   floating: true
      # )
    end

    @chart6 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Account Value")
      f.chart(zoomType: 'x')

      f.xAxis(
        type: 'datetime'
      )

      f.yAxis([
        { title: { text: "Account Value" }},
        {
          title: { text: "Bitcoin Price" },
          opposite: true
        }
      ])

      f.series(
        # type: 'spline',
        # type: 'area',
        name: 'Account Value',
        data: Metric.order(:id).pluck(:created_at, :account_value).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        name: 'Bitcoin Price',
        data: Metric.order(:id).pluck(:created_at, :bitcoin_price).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 1
      )

      f.series(
        type: 'spline',
        name: 'Hold Value',
        data: Metric.order(:id).pluck(:created_at, :bitcoin_price).map {|m| [m.first.to_i * 1000, ((m.last * 0.29808036) + 250).to_f.round(2)] },
        yAxis: 0
      )

      f.plotOptions(
        series: {
          marker: { enabled: false },
          lineWidth: 1
        }
      )

      f.tooltip(
        valuePrefix: '$'
      )

      f.legend(
        layout: 'vertical',
        align: 'left',
        verticalAlign: 'top',
        floating: true
      )
    end

    @chart7 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Moving Averages")
      f.chart(zoomType: 'x')

      f.xAxis(
        type: 'datetime',
        plotLines: find_trading_points
      )

      f.yAxis(
        title: { text: "Bitcoin Price" }
      )

      f.series(
        name: 'Bitcoin Price',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :bitcoin_price).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0,
        lineWidth: 3
      )

      f.series(
        name: '15-Minute Average',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_15_min).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        name: '30-Minute Average',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_30_min).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        # type: 'spline',
        name: '1-Hour Average',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_1_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        # type: 'spline',
        name: '4-Hour Average',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_4_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        # type: 'spline',
        name: '12-Hour Average',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_12_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        # type: 'spline',
        name: '24-Hour Average',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_24_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        type: 'spline',
        name: '3-Day Average',
        data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_3_day).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      # f.series(
      #   type: 'spline',
      #   name: '7-Day Average',
      #   data: Metric.with_averages.since(4.weeks.ago).order(:id).pluck(:created_at, :average_7_day).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
      #   yAxis: 0
      # )

      f.plotOptions(
        series: {
          marker: { enabled: false },
          lineWidth: 1
        }
      )

      f.tooltip(
        valuePrefix: '$'
      )

      f.legend(
        layout: 'vertical',
        align: 'left',
        verticalAlign: 'top',
        floating: true
      )
    end

    @chart8 = LazyHighCharts::HighChart.new('graph') do |f|
      f.title(text: "Moving Averages: 13h & 43h")
      f.chart(zoomType: 'x')

      f.xAxis(
        type: 'datetime',
        plotLines: find_trendline_trades
      )

      f.yAxis(
        title: { text: "Bitcoin Price" }
      )

      f.series(
        name: 'Bitcoin Price',
        data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :bitcoin_price).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0,
        lineWidth: 3
      )

      f.series(
        name: '13-Hour Average',
        data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_13_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        name: '43-Hour Average',
        data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_43_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        # type: 'spline',
        name: '13-Hour Average (weighted)',
        data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_13_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.series(
        # type: 'spline',
        name: '43-Hour Average (weighted)',
        data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_43_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
        yAxis: 0
      )

      f.plotOptions(
        series: {
          marker: { enabled: false },
          lineWidth: 1
        }
      )

      f.tooltip(
        valuePrefix: '$'
      )

      f.legend(
        layout: 'vertical',
        align: 'left',
        verticalAlign: 'top',
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
        # plotShadow: true,
        # plotBorderWidth: 1
      )
      f.lang(thousandsSep: ",")
      # f.colors(["#90ed7d", "#f7a35c", "#8085e9", "#f15c80", "#e4d354"])
    end

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

    def find_trading_points
      trending_down   = Metric.trending_down
      trending_up     = Metric.trending_up
      # down_trend_end  = Metric.with_averages.where("average_12_hour > average_4_hour").where("average_1_hour < average_15_min").where("average_15_min < bitcoin_price")
      # up_trend_end    = Metric.with_averages.where("average_12_hour < average_4_hour").where("average_1_hour > average_15_min").where("average_15_min > bitcoin_price")

      sell_lines = trending_down.map do |metric|
        {
          value: metric.created_at.to_i * 1000,
          width: 1,
          color: 'red',
          dashStyle: 'dot'
        }
      end

      # stop_selling_lines = down_trend_end.map do |metric|
      #   {
      #     value: metric.created_at.to_i * 1000,
      #     width: 1,
      #     color: 'orange',
      #     dashStyle: 'dash'
      #   }
      # end

      buy_lines = trending_up.map do |metric|
        {
          value: metric.created_at.to_i * 1000,
          width: 1,
          color: 'blue',
          dashStyle: 'dot'
        }
      end

      # stop_buying_lines = up_trend_end.map do |metric|
      #   {
      #     value: metric.created_at.to_i * 1000,
      #     width: 1,
      #     color: 'green',
      #     dashStyle: 'dash'
      #   }
      # end

      # sell_lines + stop_selling_lines + buy_lines + stop_buying_lines
      sell_lines + buy_lines
      # [sell_lines.first, buy_lines.first]
    end

    def find_trendline_trades
      buy_orders  = BuyOrder.trendline
      sell_orders = SellOrder.trendline

      sell_lines = sell_orders.map do |order|
        {
          value: order.created_at.to_i * 1000,
          # value: Time.zone.parse(order.gdax_created_at).to_i * 1000,
          width: 1,
          color: 'red',
          dashStyle: 'solid'
        }
      end

      buy_lines = buy_orders.map do |order|
        {
          value: order.created_at.to_i * 1000,
          # value: Time.zone.parse(order.gdax_created_at).to_i * 1000,
          width: 1,
          color: 'blue',
          dashStyle: 'solid'
        }
      end

      sell_lines + buy_lines
    end

end