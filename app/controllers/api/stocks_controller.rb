class Api::StocksController < ApplicationController

  def quote
    block = params[:block] || Chain.named.first.id
    amount = params[:amount] || 24
    chain = Chain.find(block)
    tickers = chain.tickers.last(amount.to_i)
    render json:{title: chain.label, market:chain.full_name,
      avg_price:avg_price(tickers.map{|x| x.last_price}),
      time: tickers.map{|x| x.created_at.strftime('%H:%M')},
      price:tickers.map{|x| x.last_price},
      ma5_price:tickers.map{|x| x.ma5_price},
      ma10_price:tickers.map{|x| x.ma10_price},
      col_color: columnar_color(tickers.map{|x| x.last_price})
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
      (price_array.max + price_array.min) / 2
    end

end