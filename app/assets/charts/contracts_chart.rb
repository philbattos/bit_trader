module Charts
  class ContractsChart

    def self.build_chart
      unresolved_contracts = Contract.unresolved
      resolved_contracts_daily = Contract.resolved.order("date_trunc('day', updated_at)").group("date_trunc('day', updated_at)")

      LazyHighCharts::HighChart.new('graph') do |f|
        f.title(text: "Contracts")
        f.xAxis(categories: resolved_contracts_daily.count.keys.map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%-m/%d").strip })
        f.yAxis(type: "datetime", categories: resolved_contracts_daily.count.keys.map {|c| c.in_time_zone("Mountain Time (US & Canada)").strftime("%-m/%y").strip })
        f.labels(items: [html:"Contracts (Daily)", style: {left: "40px", top: "8px", color: "black"}])
        f.series(type: 'column', name: 'Total Contracts', yAxis: 0, data: resolved_contracts_daily.count.values)
        f.series(type: 'column', name: 'ROI', yAxis: 1, data: resolved_contracts_daily.sum(:roi).values.map(&:to_f))
        # f.series(:type=> 'column', :name=> 'John',:data=> [2, 3, 5, 7, 6])
        # f.series(:type=> 'column', :name=> 'Joe',:data=> [4, 3, 3, 9, 0])

        f.yAxis [
          {title: {text: "Total Contracts", margin: 70} },
          {title: {text: "ROI"}, opposite: true},
        ]

        f.series(type: 'spline', name: 'Resolved Contracts', data: resolved_contracts_daily.count.to_a)

        f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
        # f.chart({defaultSeriesType: "column"})
      end
    end

  end
end