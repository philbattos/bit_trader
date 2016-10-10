class AccountsController < ApplicationController
  # respond_to :json

  def index
    @accounts = Account.fetch_all
    render :index
  end

  def show
    @account = Account.fetch_single(params[:id])
    render :show
  end

end