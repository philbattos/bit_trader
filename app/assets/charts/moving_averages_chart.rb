module Charts
  class MovingAveragesChart

    # Graph that tracks several moving averages (not weighted) and whether market price is trending up or down (plotOptions).
    def self.build_chart
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

    end

    # Lines indicating if market price is trending up or down (used by chart7)
    def self.find_trading_points
      trending_down = Metric.trending_down
      trending_up   = Metric.trending_up

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

  end
end