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
  start_at = Time.now
  Chain.all.each do |item|
    item.generate_ticker rescue nil
  end
  consume = Time.now - start_at
  Rails.logger.info "\n This daemon Kline running at #{Time.now}.\n"

  sleep (900 - consume)
end
