module Charts
  class OrdersChart

    def self.build_chart
      LazyHighCharts::HighChart.new('graph') do |f|
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
    end

  end
end