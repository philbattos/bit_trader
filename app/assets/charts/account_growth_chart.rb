module Charts
  class AccountGrowthChart

    def self.build_chart
      LazyHighCharts::HighChart.new('graph') do |f|
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
    end

  end
end