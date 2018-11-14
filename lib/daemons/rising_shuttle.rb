#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true
Signal.trap("TERM") do
  $running = false
end

while($running) do
  reset_time = Time.now.strftime("%H%M").to_i
  Chain.all.each do |block|
    begin
      ticker = block.market
      prev_price = block.prev_day_low_price || ticker['PrevDay']
      last_price = ticker['Last']
      point = block.point || block.build_point(weights:1)
      point.update_attributes(weights:1) if reset_time < 2
      weights = point.weights
      magnitude = Chain.amplitude(prev_price,last_price)
      if magnitude > weights
        block.bull_market_tip(magnitude,ticker)
        point.update_attributes(weights: magnitude)
      elsif magnitude < 0 && magnitude.abs > weights
        block.bear_market_tip(magnitude,ticker)
        point.update_attributes(weights: magnitude.abs)
      end
    rescue Exception => e
      Rails.logger.fatal e
    end
  end

  Rails.logger.info "\n This daemon price notice running at #{Time.now}.\n"

  sleep 60
end
