class Api::StocksController < ApplicationController

  def quote
    block = params[:block] || Chain.named.first.id
    amount = params[:amount] || 24
    chain = Chain.find(block)
    tickers = chain.tickers.last(amount.to_i)
    render json:{
      avg_price:avg_price(tickers.map{|x| x.last_price}),
      time: tickers.map{|x| x.created_at.strftime('%H:%M')},
      price: tickers.map{|x| x.last_price},
      ma5_price: tickers.map{|x| x.ma5_price},
      ma10_price: tickers.map{|x| x.ma10_price},
      volume: tickers.map{|x| x.volume },
      col_color: columnar_color(tickers.map{|x| x.volume})
    }
  end

  def init
    chains = Chain.all
    chain = Chain.first
    tickers = chain.tickers.last(48)
    render json:{
      block_ids: chains.map{|x| x.id},
      blocks: chains.map{|x| x.label},
      markets: chains.map{|x| x.full_name},
      avg_price:avg_price(tickers.map{|x| x.last_price}),
      time: tickers.map{|x| x.created_at.strftime('%H:%M')},
      price: tickers.map{|x| x.last_price},
      ma5_price: tickers.map{|x| x.ma5_price},
      ma10_price: tickers.map{|x| x.ma10_price},
      volume: tickers.map{|x| x.volume },
      col_color: columnar_color(tickers.map{|x| x.volume})
    }
  end

  def balance
    balances = Balance.sync_all
    render json:{
      balances: balances.map {|x| {title:x['Currency'],amount:x['Balance'],address:x['CryptoAddress']} if x['Balance'] > 0}
    }
  end

  private
    def columnar_color(quote_array)
      flag = 0
      color_array = []
      quote_array.each do |item|
        color_array << (item - flag > 0? 'green' : 'red')
        flag = item
      end
      return color_array
    end

    def avg_price(price_array)
      avg = (price_array.max + price_array.min) / 2
      return avg.round(2) if avg > 1
      return avg
    end

end