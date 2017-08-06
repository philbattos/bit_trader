module Charts
  class OpenContractsChart

    def self.build_chart
      unresolved_contracts = Contract.unresolved
      completed_buys       = unresolved_contracts.joins(:buy_orders).where(orders: {status: 'done'}).order(:created_at)
      completed_sells      = unresolved_contracts.joins(:sell_orders).where(orders: {status: 'done'}).order(:created_at)
      current_price        = (GDAX::MarketData.last_saved_trade.price * 0.01).to_f

      LazyHighCharts::HighChart.new('graph') do |f|
        f.title(text: "Open Contracts")

        f.xAxis(
          # title: { text: "Price" },
          # type: "linear",
          # tickPositions: unresolved_contracts.order("date_trunc('day', created_at)").map {|c| c.created_at.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip }.uniq
          # categories: unresolved_contracts.order("date_trunc('day', created_at)").map {|c| c.created_at.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip }.uniq
          plotLines: [{
            value: current_price,
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
          data: completed_buys.pluck("orders.executed_value, (EXTRACT(EPOCH FROM orders.created_at) * 1000)").map {|o| [o.first.to_f, o.last] }
        )

        f.series(
          type: 'scatter',
          name: 'Completed Sell',
          color: 'rgba(223, 83, 83, .5)',
          data: completed_sells.pluck("orders.executed_value, (EXTRACT(EPOCH FROM orders.created_at) * 1000)").map {|o| [o.first.to_f, o.last] }
          # pointStart: unresolved_contracts.order(:created_at).first
        )

        f.plotOptions(
          scatter: {
            marker: {},
            states: {},
            series: {
              pointStart: unresolved_contracts.any? ? unresolved_contracts.order(:created_at).first.try(:created_at) : 0,
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
    end

  end
end