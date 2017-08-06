class AddTrendlineRoiToMetrics < ActiveRecord::Migration[5.0]
  def change
    add_column :metrics, :trendline_roi,            :decimal
    add_column :metrics, :trendline_roi_percent,    :decimal
    add_column :metrics, :market_maker_roi,         :decimal
    add_column :metrics, :market_maker_roi_percent, :decimal
  end
end
