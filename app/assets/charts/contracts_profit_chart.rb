module Charts
  class ContractsProfitChart

    def self.build_chart
      resolved_contracts_hourly = Contract.resolved.order("date_trunc('hour', updated_at)").group("date_trunc('hour', updated_at)")

      LazyHighCharts::HighChart.new('graph') do |f|
        f.title(text: "Contracts Profit")
        f.xAxis(categories: resolved_contracts_hourly.count.keys.last(30).map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%l%P").strip })
        f.yAxis(type: "datetime", categories: resolved_contracts_hourly.count.keys.last(30).map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%_m/%d").strip })
        f.labels(items: [html:"Contracts (Hourly)", style: {left: "40px", top: "8px", color: "black"}])
        f.series(type: 'column', name: 'Completed Contracts', yAxis: 0, data: resolved_contracts_hourly.count.values.last(30))
        f.series(type: 'column', name: 'ROI', yAxis: 1, data: resolved_contracts_hourly.sum(:roi).values.last(30).map(&:to_f))
        # f.series(:type=> 'column', :name=> 'John',:data=> [2, 3, 5, 7, 6])
        # f.series(:type=> 'column', :name=> 'Joe',:data=> [4, 3, 3, 9, 0])

        f.yAxis [
          {title: {text: "Total Contracts", margin: 70} },
          {title: {text: "ROI"}, opposite: true},
        ]

        # f.series(type: 'spline', name: 'Resolved Contracts', data: resolved_contracts_hourly.count.to_a)

        f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
        # f.chart({defaultSeriesType: "column"})
      end
    end

  end
end