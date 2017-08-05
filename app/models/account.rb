class Account < ActiveRecord::Base

  def self.all_accounts
    GDAX::Connection.new.rest_client.accounts
  end

  def self.gdax_usdollar_account
    GDAX::Connection.new.rest_client.account("969b5dba-d201-43b7-ad3d-02eee4d1cdd8")
  end

  def self.gdax_bitcoin_account
    GDAX::Connection.new.rest_client.account("af65a8e8-5e33-4baf-928a-d02155793d43")
  end

  def self.balance_adjustment
    return if Order.open_orders.any? {|o| o.time_in_force == "GTT" }

    bitcoin_balance = gdax_bitcoin_account.balance
    low_cutoff      = Order::TRADING_UNITS * 0.15
    high_cutoff     = Order::TRADING_UNITS * 0.85
    optional_params = { time_in_force: 'GTT', cancel_after: 'min', post_only: true }

    if bitcoin_balance < low_cutoff * Order::ORDER_SIZE
      my_buy_price = Order.buy_price
      Order.submit_order('buy', my_buy_price, 0.05, optional_params, nil, 'adjust-balance', nil)
    elsif bitcoin_balance > high_cutoff * Order::ORDER_SIZE
      my_ask_price = Order.ask_price
      Order.submit_order('sell', my_ask_price, 0.05, optional_params, nil, 'adjust-balance', nil)
    else
      # BTC account and USD account are balanced
    end
  end

  #=================================================
    private
  #=================================================

end