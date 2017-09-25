class Api::QuotesController < ApplicationController

  def hit_tickers
    Chain.all.each do |item|
      sync_quote(item) rescue nil
    end
    render json:{code:200}
  end

private

  def amplitude(old_price,new_price)
    return ((new_price - old_price) / old_price * 100).to_i
  end

end