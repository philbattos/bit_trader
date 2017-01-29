class Add30MinAverage < ActiveRecord::Migration[5.0]
  def change
    add_column :metrics, :average_30_min, :decimal
  end
end
