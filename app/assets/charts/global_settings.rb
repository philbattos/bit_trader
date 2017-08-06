module Charts
  class GlobalSettings

    def self.build
      LazyHighCharts::HighChartGlobals.new do |f|
        # NOTE: for high-charts times, use milliseconds:
        #       find the Rails date/time, convert to epoch time with .to_i, and then multiply by 1000
        f.global(useUTC: false)
        f.chart(
          backgroundColor: {
            linearGradient: [0, 0, 500, 500],
            stops: [
              [0, "rgb(255, 255, 255)"],
              [1, "rgb(240, 240, 255)"]
            ]
          },
          borderWidth: 2,
          plotBackgroundColor: "rgba(255, 255, 255, .9)",
          # plotShadow: true,
          # plotBorderWidth: 1
        )
        f.lang(thousandsSep: ",")
        # f.colors(["#90ed7d", "#f7a35c", "#8085e9", "#f15c80", "#e4d354"])
      end
    end

  end
end