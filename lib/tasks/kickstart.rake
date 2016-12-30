desc "Start running bot: update orders & contracts; make new trades"
task kickstart: :environment do
  Trader.start
end