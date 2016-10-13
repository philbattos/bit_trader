class CreateAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :accounts do |t|
      t.string :gdax_id
      t.string :gdax_currency
      t.string :gdax_balance
      t.string :gdax_hold
      t.string :gdax_available
      t.string :gdax_profile_id

      t.timestamps
    end
  end
end
