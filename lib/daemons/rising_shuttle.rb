#!/usr/bin/env ruby
ENV["RAILS_ENV"] ||= "development"
#获取当前文件的绝对路径
root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

Rails.logger = logger = Logger.new STDOUT

$running = true

Signal.trap('TERM') do
  $running = false
end

while($running) do
  Chain.all.each do |block|
    ticker = block.market rescue nil
    day_price = ticker['PrevDay']
    last_price = ticker['Last']
    weights = block.point.try(:weights) || 5
    magnitude = Chain.amplitude(day_price,last_price)
    if magnitude > weights
      block.bull_market_tip(magnitude,ticker)
    elsif magnitude < -weights
      block.bear_market_tip(magnitude,ticker)
    end
  end
  sleep 60
end