class AddWeightedAveragesToMetrics < ActiveRecord::Migration[5.0]
  def change
    add_column :metrics, :average_weighted_30_minute, :decimal
    add_column :metrics, :average_weighted_1_hour,    :decimal
    add_column :metrics, :average_weighted_4_hour,    :decimal
    add_column :metrics, :average_weighted_6_hour,    :decimal
    add_column :metrics, :average_weighted_10_hour,   :decimal
    add_column :metrics, :average_weighted_21_hour,   :decimal
    add_column :metrics, :average_weighted_25_hour,   :decimal

    add_index :metrics, :average_weighted_30_minute
    add_index :metrics, :average_weighted_1_hour
    add_index :metrics, :average_weighted_4_hour
    add_index :metrics, :average_weighted_6_hour
    add_index :metrics, :average_weighted_10_hour
    add_index :metrics, :average_weighted_21_hour
    add_index :metrics, :average_weighted_25_hour
  end
end
