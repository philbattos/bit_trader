module Charts
  class TrendlineContractsChart

    def self.build_chart
      LazyHighCharts::HighChart.new('graph') do |f|
        f.title(text: "Trendline Contracts")
        f.subtitle(text: "Trendline Values")
        f.chart(zoomType: 'x')

        f.xAxis(
          type: 'datetime',
          crosshair: true
        )

        f.yAxis([
          {
            title: { text: "Trendline Contracts" },
            labels: { format: '${value} ROI' }
          },
          {
            title: { text: "Bitcoin Price" },
            opposite: true
          }
        ])

        f.series(
          name: 'Bitcoin Price',
          type: 'spline',
          data: Metric.where("id > 19400").order(:id).pluck(:created_at, :bitcoin_price).map {|m| [m.first.to_i * 1000, m.last.to_f.round(2)] },
          yAxis: 1
        )

        f.series(
          name: 'Trendlines',
          type: 'column',
          data: Contract.trendline.where("id > 56250").order(:created_at).pluck(:created_at, :roi).map {|c| [c.first.to_i * 1000, c.last.to_f.round(2)] }
          tooltip: { valueSuffix: ' roi' }
        )

        f.plotOptions(
          series: {
            marker: { enabled: false },
            lineWidth: 1
          }
        )

        f.tooltip(
          shared: true
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