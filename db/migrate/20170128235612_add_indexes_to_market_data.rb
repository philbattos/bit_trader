class AddIndexesToMarketData < ActiveRecord::Migration[5.0]
  def change
    add_index :market_data, :gdax_time
    add_index :market_data, :price
  end
end
