class AddStopOrderFields < ActiveRecord::Migration[5.0]
  def change
    add_column :orders, :stop_type,  :string
    add_column :orders, :stop_price, :decimal
  end
end
