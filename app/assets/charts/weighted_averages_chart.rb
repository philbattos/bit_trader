module Charts
  class WeightedAveragesChart

    def self.build_chart
      LazyHighCharts::HighChart.new('graph') do |f|
        f.title(text: "Weighted Moving Averages")
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
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :bitcoin_price).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0,
          lineWidth: 3
        )

        f.series(
          name: '30-Minute Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_30_minute).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '1-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_1_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '4-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_4_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '6-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_6_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '10-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_10_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          type: 'spline', # remove?
          name: '13-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_13_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '21-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_21_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '25-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_25_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          type: 'spline', # remove?
          name: '43-Hour Average',
          data: Metric.with_averages.where("id > ?", 21690).order(:id).pluck(:created_at, :average_weighted_43_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
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
    end

    def self.find_trendline_trades
      attempted_buy_orders      = BuyOrder.trendline.canceled
      attempted_sell_orders     = SellOrder.trendline.canceled
      completed_buy_orders      = BuyOrder.trendline.done
      completed_sell_orders     = SellOrder.trendline.done
      ema_crossover_buy_orders  = BuyOrder.trendline.ema_crossover
      ema_crossover_sell_orders = SellOrder.trendline.ema_crossover

      attempted_sell_lines = attempted_sell_orders.map do |order|
        {
          value: order.created_at.to_i * 1000,
          # value: Time.zone.parse(order.gdax_created_at).to_i * 1000,
          width: 1,
          color: 'red',
          dashStyle: 'dot'
        }
      end

      attempted_buy_lines = attempted_buy_orders.map do |order|
        {
          value: order.created_at.to_i * 1000,
          # value: Time.zone.parse(order.gdax_created_at).to_i * 1000,
          width: 1,
          color: 'green',
          dashStyle: 'dot'
        }
      end

      completed_sell_lines = completed_sell_orders.map do |order|
        {
          value: (order.stop_order? ? order.updated_at.to_i : order.created_at.to_i) * 1000,
          # value: Time.zone.parse(order.gdax_created_at).to_i * 1000,
          width: 1,
          color: 'red',
          dashStyle: 'solid'
        }
      end

      completed_buy_lines = completed_buy_orders.map do |order|
        {
          value: (order.stop_order? ? order.updated_at.to_i : order.created_at.to_i) * 1000,
          # value: Time.zone.parse(order.gdax_created_at).to_i * 1000,
          width: 1,
          color: 'green',
          dashStyle: 'solid'
        }
      end

      ema_buy_lines = ema_crossover_buy_orders.map do |order|
        {
          value: order.created_at.to_i * 1000,
          width: 1,
          color: 'blue',
          dashStyle: 'LongDashDotDot'
        }
      end

      ema_sell_lines = ema_crossover_sell_orders.map do |order|
        {
          value: order.created_at.to_i * 1000,
          width: 1,
          color: 'orange',
          dashStyle: 'LongDashDotDot'
        }
      end

      attempted_sell_lines + attempted_buy_lines + completed_sell_lines + completed_buy_lines + ema_buy_lines + ema_sell_lines
    end

  end
end