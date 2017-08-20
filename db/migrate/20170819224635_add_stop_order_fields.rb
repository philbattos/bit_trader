class AddStopOrderFields < ActiveRecord::Migration[5.0]
  def change
    add_column :orders, :stop_type,  :string,  null: true
    add_column :orders, :stop_price, :decimal, null: true
  end
end
