class Account < ActiveRecord::Base

  # def self.fetch_all
  #   request_path = '/accounts'
  #   request_info = "#{timestamp}GET#{request_path}"
  #   request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

  #   send_get_request(request_path, request_hash)
  # end

  # def self.fetch_single(account_id)
  #   request_path = "/accounts/#{account_id}"
  #   request_info = "#{timestamp}GET#{request_path}"
  #   request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

  #   send_get_request(request_path, request_hash)
  # end

  #=================================================
    private
  #=================================================

end