desc "Start running bot: poll exchange for account and order info."
task kickstart: :environment do
  Market.poll
end