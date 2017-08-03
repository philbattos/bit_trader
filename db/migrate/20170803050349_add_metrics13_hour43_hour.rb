class AddMetrics13Hour43Hour < ActiveRecord::Migration[5.0]
  def change
    add_column :metrics, :average_13_hour, :decimal
    add_column :metrics, :average_43_hour, :decimal
    add_column :metrics, :average_weighted_13_hour, :decimal
    add_column :metrics, :average_weighted_43_hour, :decimal
  end
end
