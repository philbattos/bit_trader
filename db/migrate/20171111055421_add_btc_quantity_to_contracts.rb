class AddBtcQuantityToContracts < ActiveRecord::Migration[5.0]
  def change
    add_column :contracts, :btc_quantity, :decimal, null: true
  end
end
