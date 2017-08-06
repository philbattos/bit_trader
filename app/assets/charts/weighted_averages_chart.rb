module Charts
  class WeightedAveragesChart

    def self.build_chart
      LazyHighCharts::HighChart.new('graph') do |f|
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
          name: '30-Minute Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_30_minute).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '1-Hour Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_1_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '4-Hour Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_4_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '6-Hour Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_6_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '10-Hour Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_10_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          type: 'spline', # remove?
          name: '13-Hour Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_13_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '21-Hour Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_21_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          name: '25-Hour Average',
          data: Metric.with_averages.where("id > ?", 21253).order(:id).pluck(:created_at, :average_weighted_25_hour).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 0
        )

        f.series(
          type: 'spline', # remove?
          name: '43-Hour Average',
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
    end

    def self.find_trendline_trades
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
          color: 'green',
          dashStyle: 'solid'
        }
      end

      sell_lines + buy_lines
    end

  end
end