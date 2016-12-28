source 'https://rubygems.org'

#-------------------------------------------------
#    Rails default gems
#-------------------------------------------------
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails',        '5.0.0'
gem 'sass-rails',   '~> 5.0'
gem 'uglifier',     '>= 1.3.0'              # Use Uglifier as compressor for JavaScript assets
gem 'coffee-rails', '~> 4.1.0'
gem 'jquery-rails'                          # Use jquery as the JavaScript library
gem 'turbolinks'                            # Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'jbuilder',     '~> 2.0'
gem 'sdoc',         '~> 0.4.0', group: :doc # bundle exec rake doc:rails generates the API under doc/api.

#-------------------------------------------------
#    Added gems
#-------------------------------------------------
gem 'coinbase'                              # Ruby wrapper for the Coinbase API
# gem 'coinbase-exchange'                     # Client library for Coinbase Exchange
gem 'coinbase-exchange', github: "philbattos/coinbase-exchange-ruby" # using forked version since some updates were necessary
# gem 'coinbase-exchange', path: "/Users/philbattos/.rbenv/versions/2.3.0/lib/ruby/gems/2.3.0/gems/coinbase-exchange-0.1.2"
gem 'faraday'                               # HTTP client
gem 'em-http-request'                       # required by coinbase gem for authentication
gem 'pg'                                    # use postgres db (required by Heroku)
gem 'puma'                                  # server that supports ActionCable (Rails 5)

group :development, :test do
  gem 'pry'                                 # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'dotenv-rails'                        # Set and load environment variables
end

group :development do
  gem 'web-console', '~> 2.0'               # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'spring'                              # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
end

ruby "2.3.0"                                # used by Heroku to specify Ruby version