class Api::QuotesController < ApplicationController
  #每30分钟获取一直价格，生成历史行情
  def hit_tickers
    Chain.all.each do |item|
      item.generate_ticker rescue nil
      extremum_report(item)
      if item.point && item.point.state
        middle_analysis(item)
      end
    end
    render json:{code:200}
  end

  #每5分钟获取一次最新价格，根据价格涨幅做买卖通知 低频交易
  def hit_markets
    Chain.all.each do |item|
      if item.point && item.point.state
        quote_macd_analysis(item)
      end
    end
    render json:{code:200}
  end

  #每2分钟获取一次最新价格，高频交易
  def hit_high_markets
    Chain.all.each do |item|
      if item.point && item.point.frequency
        high_analysis(item)
      end
    end
    render json:{code:200}
  end

  #每天清空一次历史交易记录
  def hit_clear_business_orders
    Order.where(deal:1,repurchase:true).destroy_all
    Order.where(deal:0).destroy_all
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

  def quote_macd_analysis(block)
    market = block.market
    high_price = market.first['High']
    low_price = market.first['Low']
    bid_price = market.first['Bid']
    ask_price = market.first['Ask']
    recent = block.tickers.last(7)
    stock = block.tickers.last(2).map {|x| x.last_price }
    diff_dea_last = recent.map {|x| x.macd_diff - x.macd_dea }
    if stock[-1] > stock[-2]
      if bid_price * 1.01 > high_price && diff_dea_last[-1] > 0
        sell_quote_market(block,market)
      elsif ask_price < low_price * 1.01 && diff_dea_last[-1] < 0
        buy_quote_market(block,market)
      end
    end
  end

  #根据 MACD
  def middle_analysis(block)
    market = block.market
    recent = block.tickers.last(7)
    macd_dea_last = recent.map {|x| x.macd_dea }
    macd_diff_last = recent.map {|x| x.macd_diff }
    diff_dea_last = recent.map {|x| x.macd_diff - x.macd_dea }
    if diff_dea_last[-1] < 0 && diff_dea_last[-2] > 0 && diff_dea_last[0..-2].min > 0
      sell_quote_market(block,market)
    elsif diff_dea_last[-1] > 0 && macd_diff_last[-2] < 0 && diff_dea_last[0..-2].max < 0
      buy_quote_market(block,market)
    end
  end

  def sell_quote_market(block,market)
    last_price = market.first['Bid']
    buy = block.low_buy_business.order(price: :asc).first
    balance = block.balance
    if buy
      if balance > 0 && last_price > buy.price * 1.05
        sell_chain(block,buy.amount,last_price)
      end
    else
      if balance > 0
        sell_chain(block,balance,last_price)
      end
    end
  end

  def buy_quote_market(block,market)
    last_price = market.first['Ask']
    point = block.point
    avl_money = block.money #可用的有效现金
    buy_money = point.total_value
    if avl_money > 1
      money = avl_money > buy_money ? buy_money : avl_money
      amount = (money/last_price).to_d.round(5,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
    end
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

  def extremum_report(block)
    quotes = block.tickers.last(48)
    td_quotes = quotes.map {|x| x.last_price}
    macd_quotes = quotes.map {|x| x.macd_diff - macd_dea}
    if work_time?
      if td_quotes.max == td_quotes[-1]
        User.sms_batch("#{block.block},行情最高点,价格:#{td_quotes[-1]} #{block.currency},时间:#{Time.now.strftime('%H:%M')}")
      elsif td_quotes.min == td_quotes[-1]
        User.sms_batch("#{block.block},行情最低点,价格:#{td_quotes[-1]} #{block.currency},时间:#{Time.now.strftime('%H:%M')}")
      end
      if macd_quotes[-1] > 0 && macd_quotes[-2] < 0
        User.sms_notice("#{block.block},上涨金叉点,价格:#{td_quotes[-1]} #{block.currency},时间:#{Time.now.strftime('%H:%M')}")
      end
    end
  end

  def high_analysis(block)
    market = block.market
    point = block.point
    stock = block.tickers.last
    last_price = stock.last_price #最近半小时报价
    buy_price = market.first['Ask'] #卖出低单价
    sell_price = market.first['Bid'] #买入最高单价
    money = block.money #可用的有效现金
    balance = block.balance #持有的区块数
    low_buy = block.high_buy_business.order(price: :asc).first #当前存在的有效买单
    high_total_val = block.high_buy_business.map {|x| x.total}.sum
    if low_buy && sell_price > low_buy.price * 1.02 && balance > 0
      if balance > low_buy.amount
        high_sell_chain(block,low_buy.amount,sell_price)
      else
        high_sell_chain(block,balance,sell_price)
      end
    end
    if buy_price < last_price && high_total_val < point.high_value && money > point.high_price
      if stock.ma5_price > stock.ma10_price && buy_price  < last_price * 1.005
        amount = (point.high_price/buy_price).to_d.round(4,:truncate).to_f
        high_buy_chain(block,amount,buy_price)
      elsif stock.ma5_price < stock.ma10_price && buy_price * 1.01 < last_price
        amount = (point.high_price/buy_price).to_d.round(4,:truncate).to_f
        high_buy_chain(block,amount,buy_price)
      end
    end
  end

  def high_buy_chain(block,amount,price)
    order = Order.new
    order.deal = 1
    order.frequency = true
    order.chain_id = block.id
    order.amount = amount
    order.price = price
    order.save
  end

  def high_sell_chain(block,amount,price)
    order = Order.new
    order.deal = 0
    order.frequency = true
    order.chain_id = block.id
    order.amount = amount
    order.price = price
    order.save
  end

  def work_time?
    current = Time.now.strftime('%H').to_i
    return true if current < 22 || current > 10
    false
  end

end