class AddAveragesToMetrics < ActiveRecord::Migration[5.0]
  def change
    add_column :metrics, :average_15_min,  :decimal
    add_column :metrics, :average_1_hour,  :decimal
    add_column :metrics, :average_4_hour,  :decimal
    add_column :metrics, :average_12_hour, :decimal
    add_column :metrics, :average_24_hour, :decimal
    add_column :metrics, :average_3_day,   :decimal
    add_column :metrics, :average_7_day,   :decimal
    add_column :metrics, :average_15_day,  :decimal
    add_column :metrics, :average_30_day,  :decimal
  end
end
