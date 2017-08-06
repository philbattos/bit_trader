# The charts in this file were removed from app/controllers/traders_controller.rb

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

# Graph that tracks several moving averages (not weighted) and whether market price is trending up or down (plotOptions).
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

# Lines indicating if market price is trending up or down (used by chart7)
def find_trading_points
  trending_down   = Metric.trending_down
  trending_up     = Metric.trending_up

  sell_lines = trending_down.map do |metric|
    {
      value: metric.created_at.to_i * 1000,
      width: 1,
      color: 'red',
      dashStyle: 'dot'
    }
  end

  buy_lines = trending_up.map do |metric|
    {
      value: metric.created_at.to_i * 1000,
      width: 1,
      color: 'blue',
      dashStyle: 'dot'
    }
  end

  sell_lines + buy_lines
end