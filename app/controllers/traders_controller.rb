class TradersController < ApplicationController
  # respond_to :json

  def update
    Rails.logger.info "params: #{params.inspect}"
    @trader = Trader.find(params[:id])
    puts "@trader: #{@trader.inspect}"
    if @trader.update(is_active: params[:is_active])
      puts "updated trader"
      # refresh orders page
      redirect_to :back
    else
      puts "error updating trader"
      # render error
      redirect_to :back
    end
  end

end