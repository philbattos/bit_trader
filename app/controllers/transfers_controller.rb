require 'coinbase/wallet'

class TransfersController < ApplicationController
  # respond_to :json

  def index
    # @transfer = Transfer
    # @coinbase_account = Coinbase.fetch_account

    # Use coinbase gem to fetch Coinbase account info
    client = Coinbase::Wallet::AsyncClient.new(
      api_key:    ENV['COINBASE_API_KEY'],
      api_secret: ENV['COINBASE_API_SECRET']
    )
    @coinbase_account = client.primary_account
    # @coinbase_account = client.accounts
    # @coinbase_account = client.trade_history('4e8ad8f1-70a4-5882-90f4-a3ee30897c36')
    # @coinbase_account = client.account('4e8ad8f1-70a4-5882-90f4-a3ee30897c36').addresses
    # @coinbase_account = client.account('4e8ad8f1-70a4-5882-90f4-a3ee30897c36').transactions

    render :index
  end

  # Endpoint action that initiates transfer from Coinbase account to GDAX Exchange account.
  # The transfer amount is a required parameter. The Coinbase & GDAX account IDs are optional.
  # curl -X POST -H "Content-Type: application/json" localhost:3000/transfers.json -d '{"transfer": {"amount": 0.001}}'
  def create
    transfer = Transfer.new(params[:transfer][:amount]).complete
    render json: transfer
  end

end