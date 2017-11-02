class Api::StocksController < ApplicationController

  def quote
    block = params[:block] || Chain.named.first.id
    amount = params[:amount] || 24
    chain = Chain.find(block)
    tickers = chain.tickers.last(amount.to_i)
    render json:{title: chain.label, market:chain.full_name,
      time: tickers.map{|x| x.created_at.strftime('%H:%M')},
      price:tickers.map{|x| x.last_price},
      ma5_price:tickers.map{|x| x.ma5_price},
      ma10_price:tickers.map{|x| x.ma10_price}
    }
  end
end