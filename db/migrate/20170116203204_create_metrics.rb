class CreateMetrics < ActiveRecord::Migration[5.0]
  def change
    create_table :metrics do |t|
      t.decimal :us_dollar_balance
      t.decimal :bitcoin_balance
      t.decimal :bitcoin_price
      t.decimal :account_value
      t.decimal :total_roi
      t.decimal :roi_percent

      t.integer :unresolved_contracts
      t.integer :matched_contracts
      t.integer :open_orders

      t.timestamps
    end
  end
end
