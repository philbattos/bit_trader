class ChangeIntegerColumnLimit < ActiveRecord::Migration[5.0]
  def change
    change_column :market_data, :trade_id, :integer, limit: 8
  end
end
