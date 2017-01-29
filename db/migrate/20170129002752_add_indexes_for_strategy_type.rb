class AddIndexesForStrategyType < ActiveRecord::Migration[5.0]
  def change
    add_index :orders,    :strategy_type
    add_index :contracts, :strategy_type
  end
end
