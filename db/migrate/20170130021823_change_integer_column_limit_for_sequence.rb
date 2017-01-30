class ChangeIntegerColumnLimitForSequence < ActiveRecord::Migration[5.0]
  def change
    change_column :market_data, :sequence, :integer, limit: 8
  end
end
