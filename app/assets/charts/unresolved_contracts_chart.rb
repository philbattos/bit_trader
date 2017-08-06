module Charts
  class UnresolvedContractsChart

    def self.build_chart
      recent_metrics       = Metric.order("id desc").limit(350) # 2+ days of metrics
      incomplete_contracts = recent_metrics.pluck(:created_at, :unresolved_contracts).map {|m| [m.first.to_i * 1000, m.last]}
      # active_orders        = recent_metrics.pluck(:created_at, :open_orders).map {|m| [m.first.to_i * 1000, m.last]}

      LazyHighCharts::HighChart.new('graph') do |f|
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
          data: incomplete_contracts,
          yAxis: 0
        )

        # f.series(
        #   type: 'column',
        #   name: 'Active Orders',
        #   data: active_orders
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
    end

  end
end