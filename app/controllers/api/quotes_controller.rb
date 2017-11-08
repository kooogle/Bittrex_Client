class Api::QuotesController < ApplicationController
  #每30分钟获取一直价格，生成历史行情
  def hit_tickers
    Chain.all.each do |item|
      item.generate_ticker rescue nil
    end
    render json:{code:200}
  end
  #每10分钟获取一次最新价格，根据价格涨幅做买卖通知
  def hit_markets
    Chain.all.each do |item|
      if item.point && item.point.state
        quote_analysis(item)
      end
    end
    render json:{code:200}
  end

private

  def amplitude(old_price,new_price)
    return ((new_price - old_price) / old_price * 100).to_i
  end

  def quote_report(market)
    market = block.market
    if block.high_nearby(market['Bid']) || market['Bid'] > block.high
      string = "#{self.currency}-#{self.block} 接近最高价，买一价：#{market['Bid']}"
    elsif block.low_nearby(market['Ask']) || market['Ask'] < block.low
      string = "#{self.currency}-#{self.block} 接近最低价，买一价：#{market['Ask']}"
    end
    User.sms_yunpian(string)
  end

  def quote_analysis(block)
    market = block.market
    ma5_price = block.tickers.last.ma5_price
    ma10_price = block.tickers.last.ma10_price
    if ma5_price > ma10_price
      sell_analysis(block,market)
    elsif ma5_price < ma10_price
      buy_analysis(block,market)
    end
  end

  def buy_analysis(block,market)
    last_price = market.first['Ask']
    low_price = market.first['Low']
    point = block.point
    currency = block.money
    money = block.available_money
    if last_price < block.low && last_price > low_price && money > 0
      amount = (money/last_price).to_d.round(2,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
    elsif block.low_nearby(last_price)
      if money > point.unit * last_price
        amount = (money/last_price).to_d.round(2,:truncate).to_f
        buy_chain(block,point.unit,last_price) if amount > 0
      elsif currency < point.unit * last_price
        amount = (currency/last_price).to_d.round(2,:truncate).to_f
        buy_chain(block,amount,last_price) if amount > 0
      end
    elsif block.kling_down_up_point?
      buy_chain(block,point.unit,last_price) if currency > point.unit * last_price
      if currency < point.unit * last_price
        amount = (currency/last_price).to_d.round(2,:truncate).to_f
        buy_chain(block,amount,last_price) if amount > 0
      end
    end
  end

  def sell_analysis(block,market)
    last_price = market.first['Bid']
    high_price = market.first['High']
    point = block.point
    balance = block.balance
    if last_price > block.greater_income && balance > 0
      if last_price > block.high && last_price < high_price
        batch_part_sell(block,point.unit,balance,last_price,0.3)
      elsif block.high_nearby(last_price)
        batch_part_sell(block,point.unit,balance,last_price,0.25)
      elsif block.kling_up_down_point?
        batch_part_sell(block,point.unit,balance,last_price,0.2)
      end
    elsif last_price < block.last_buy_price * 0.9382
      User.sms_yunpian("#{block.full_name},价格过低,请留意行情!")
    end
  end

  def batch_part_sell(block,amount,balance,price,percent)
    sell_chain(block,(balance * percent).round(2),price) if balance > amount
    sell_chain(block,amount,price) if balance < amount
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