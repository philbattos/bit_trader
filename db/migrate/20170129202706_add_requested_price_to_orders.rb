class AddRequestedPriceToOrders < ActiveRecord::Migration[5.0]
  def change
    add_column :orders, :requested_price, :decimal
    add_column :orders, :executed_value,  :decimal

    rename_column :orders, :price, :filled_price

    add_index :orders, :requested_price
    add_index :orders, :executed_value
  end
end
