class AddStrategyTypes < ActiveRecord::Migration[5.0]
  def change
    add_column :contracts, :strategy_type, :string
    add_column :orders,    :strategy_type, :string

    add_index :orders, :contract_id
    add_index :orders, :status
    add_index :orders, :price
    add_index :orders, :fees

    add_index :orders, :quantity
    add_index :contracts, :status
    add_index :contracts, :roi

    add_index :metrics, :bitcoin_price
    add_index :metrics, :account_value
    add_index :metrics, :average_15_min
    add_index :metrics, :average_1_hour
    add_index :metrics, :average_4_hour
    add_index :metrics, :average_12_hour
    add_index :metrics, :average_24_hour
    add_index :metrics, :average_3_day
    add_index :metrics, :average_7_day
    add_index :metrics, :average_15_day
    add_index :metrics, :average_30_day
  end
end
