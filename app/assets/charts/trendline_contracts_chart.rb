module Charts
  class TrendlineContractsChart

    def self.build_chart
      LazyHighCharts::HighChart.new('graph') do |f|
        f.title(text: "Trendline Contracts")
        f.subtitle(text: "Trendline Values")
        f.chart(zoomType: 'xy')

        f.xAxis(
          type: 'datetime',
          crosshair: true
        )

        f.yAxis([
          { title: { text: "Trendline Contracts" }},
          {
            title: { text: "Bitcoin Price" },
            opposite: true
          }
        ])

        f.series(
          name: 'Bitcoin Price',
          type: 'spline',
          data: Metric.order(:id).pluck(:created_at, :bitcoin_price).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 1
        )

        f.series(
          name: 'Trendlines',
          type: 'column',
          data: Contract.trendline.order(:created_at).pluck(:created_at, :roi).map {|c| [c.first.to_i * 1000, c.last.to_f.round(2)] }
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