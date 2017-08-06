module Charts
  class AccountValueChart

    def initialize
      build_chart
    end

    def build_chart
      LazyHighCharts::HighChart.new('graph') do |f|
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
    end

  end
end