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
      macd_val: tickers.map{|x| x.macd_diff - x.macd_dea },
      macd_col: macd_color(tickers.map{|x| x.macd_diff - x.macd_dea })
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
      macd_val: tickers.map{|x| x.macd_diff - x.macd_dea },
      macd_col: macd_color(tickers.map{|x| x.macd_diff - x.macd_dea })
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
    focus = Point.all.map {|x| {id:x.chain_id,block:x.chain.block,amount: balances[x.chain.block] || 0.0,market:x.chain.market.first}}.unshift({block:'USDT',amount:balances['USDT']})
    render json:{balances: focus}
  end

  def buy
    block = Chain.find(params[:block])
    ava_money = block.money
    if ava_money > 0
      chain_money = block.point.total_value
      price = block.market.first['Ask']
      buy_money = ava_money > chain_money ? chain_money : ava_money
      amount = buy_money.to_i / price
      amount = amount > 1 ? amount.to_d.round(4,:truncate).to_f : amount.to_d.round(4,:truncate).to_f
      buy_chain(block,amount,price)
    end
    render json:{code:200}
  end

  def sell
    block = Chain.find(params[:block])
    balance = block.balance
    if balance > 0
      chain_money = block.point.total_value
      price = block.market.first['Bid']
      sell_amount = chain_money / price
      amount = balance > sell_amount ? sell_amount : balance
      amount = amount > 1 ? amount.to_d.round(4,:truncate).to_f : amount.to_d.round(4,:truncate).to_f
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