class Api::StocksController < ApplicationController

  def quote
    block = params[:block] || Chain.first.id
    amount = params[:amount] || 48
    chain = Chain.find(block)
    tickers = chain.tickers.last(amount.to_i)
    render json:{
      avg_price:avg_price(tickers.map{|x| x.last_price}),
      time: tickers.map{|x| x.created_at.strftime('%H:%M')},
      price: tickers.map{|x| x.last_price},
      ma5_price: tickers.map{|x| x.ma5_price},
      ma10_price: tickers.map{|x| x.ma10_price},
      macd_diff: tickers.map{|x| x.macd_diff },
      macd_color: macd_color(tickers.map{|x| x.macd_diff })
    }
  end

  def init
    chains = Chain.all
    chain = Chain.first
    tickers = chain.tickers.last(48)
    render json:{
      block_ids: chains.map{|x| x.id },
      blocks: chains.map{|x| x.block },
      markets: chains.map{|x| x.full_name},
      avg_price:avg_price(tickers.map{|x| x.last_price}),
      time: tickers.map{|x| x.created_at.strftime('%H:%M')},
      price: tickers.map{|x| x.last_price},
      ma5_price: tickers.map{|x| x.ma5_price},
      ma10_price: tickers.map{|x| x.ma10_price},
      macd_diff: tickers.map{|x| x.macd_diff },
      macd_color: macd_color(tickers.map{|x| x.macd_diff })
    }
  end

  def balance
    balances = {}
    bals = Balance.sync_all
    bals.each do |item|
      if item['Balance'] > 0
        balances[item['Currency']] = item['Balance'] > 1 ? item['Balance'].round(2) : item['Balance'].round(4)
      end
    end
    focus = Point.all.map {|x| {id:x.chain_id,block:x.chain.block,price: x.chain.buy_price,amount: balances[x.chain.block] || 0.0,cost: x.chain.buy_cost,market:x.chain.market.first}}.unshift({block:'USDT',amount:balances['USDT']})
    render json:{balances: focus}
  end

  def buy
    block = Chain.find(params[:block])
    ava_money = block.money
    if ava_money > 1
      chain_money = block.point.low_price
      price = block.market.first['Ask']
      buy_money = ava_money * 0.9975 > chain_money ? chain_money : ava_money * 0.9975
      amount = buy_money.to_i / price
      amount = amount > 1 ? amount.to_d.round(5,:truncate).to_f : amount.to_d.round(5,:truncate).to_f
      buy_chain(block,amount,price)
    end
    render json:{code:200}
  end

  def sell
    block = Chain.find(params[:block])
    balance = block.balance
    buy = block.low_buy_business.first
    buy = block.high_buy_business.first if buy.nil?
    price = block.market.first['Bid']
    if balance > 0
      if buy
        amount = balance > buy.amount ? buy.amount : balance
      else
        amount = balance
      end
      sell_chain(block,amount,price)
    end
    render json:{code:200}
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

    def macd_color(macd_array)
      color_array = []
      macd_array.each do |item|
        color_array << (item > 0? 'green' : 'red')
      end
      return color_array
    end

    def avg_price(price_array)
      avg = (price_array.max + price_array.min) / 2
      return avg.round(2) if avg > 1
      return avg
    end

    def sell_chain(block,amount,price)
      order = Order.new
      order.deal = 0
      order.chain_id = block.id
      order.amount = amount
      order.price = price
      order.save
    end

    def buy_chain(block,amount,price)
      order = Order.new
      order.deal = 1
      order.chain_id = block.id
      order.amount = amount
      order.price = price
      order.save
    end

end