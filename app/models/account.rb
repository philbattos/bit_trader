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

  #=================================================
    private
  #=================================================

end