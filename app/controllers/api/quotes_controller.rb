class Api::QuotesController < ApplicationController
  #每30分钟获取一直价格，生成历史行情
  def hit_tickers
    Chain.all.each do |item|
      item.generate_ticker rescue nil
      extremum_report(item)
      if item.point && item.point.state
        middle_ma_business(item)
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
        sell_macd_market(block,market)
      elsif ask_price < low_price * 1.01 && diff_dea_last[-1] < 0
        buy_macd_market(block,market)
      end
    end
  end

  #根据 MACD
  def middle_macd_business(block)
    market = block.market
    recent = block.tickers.last(5)
    diff_dea_last = recent.map {|x| x.macd_diff - x.macd_dea }
    if diff_dea_last[-1] < 0 && diff_dea_last[-2] > 0 && diff_dea_last[0..-2].min > 0
      sell_macd_market(block,market)
    elsif diff_dea_last[-1] > 0 && diff_dea_last[-2] < 0 && diff_dea_last[0..-2].max < 0
      buy_macd_market(block,market)
    end
  end

  def sell_macd_market(block,market)
    last_price = market.first['Bid']
    buy = block.low_buy_business.first
    balance = block.balance
    if buy && balance > 0 && last_price > buy.price * 1.01
      amount = balance > buy.amount ? buy.amount : balance
      sell_chain(block,amount,last_price)
    end
  end

  def buy_macd_market(block,market)
    last_price = market.first['Ask']
    point = block.point
    avl_money = block.money
    buy_money = point.low_price
    total_money = point.total_value
    had_total = block.low_buy_business.map {|x| x.total}.sum
    if avl_money > 1 && had_total < total_money
      money = avl_money > buy_money ? buy_money : avl_money
      amount = (money/last_price).to_d.round(5,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
    end
  end

  def middle_ma_business(block)
    market = block.market
    recent = block.tickers.last(2)
    ma_diff = recent.map {|x| x.ma5_price - x.ma10_price }
    if ma_diff[-1] > 0 && ma_diff[-2]
      buy_ma_market(block,market)
    elsif  ma_diff[-1] < 0 && ma_diff[-2]
      sell_ma_market(block,market)
    end
  end

  def buy_ma_market(block,market)
    last_price = market.first['Ask']
    point = block.point
    avl_money = block.money
    buy_money = point.high_price
    total_money = point.high_value
    had_total = block.high_buy_business.map {|x| x.total}.sum
    if avl_money > 1 && had_total < total_money
      money = avl_money > buy_money ? buy_money : avl_money
      amount = (money/last_price).to_d.round(4,:truncate).to_f
      high_buy_chain(block,amount,last_price) if amount > 0
    elsif avl_money > 1 && had_total > total_money
      full_chain_notice(block)
    end
  end

  def sell_ma_market(block,market)
    last_price = market.first['Bid']
    buy = block.high_buy_business.first
    balance = block.balance
    if buy && balance > 0 && last_price > buy.price * 1.01
      amount = balance > buy.amount ? buy.amount : balance
      high_sell_chain(block,amount,last_price)
    elsif buy && last_price < buy.price
      empty_chain_notice(block)
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
    ma_diff = quotes[-2..-1].map {|x| x.ma5_price - x.ma10_price}
    td_quotes = quotes.map {|x| x.last_price}
    macd_quotes = quotes.map {|x| x.macd_diff - x.macd_dea}
    if td_quotes.max == td_quotes[-1]
      chain_up_notice(block)
    elsif td_quotes.min == td_quotes[-1]
      chain_down_notice(block)
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

  def work_time
    current = Time.now.strftime('%H').to_i
    return true if  current > 9 && current < 22
    nil
  end

  def chain_up_notice(block)
    title = "#{block.block} 价格上涨"
    desp = "价格: #{block.tickers.last.last_price} USDT, 时间: #{Time.now.strftime('%F %T')}"
    User.wechat_group_notice(title,desp)
  end

  def chain_down_notice(block)
    title = "#{block.block} 价格下跌"
    desp = "价格: #{block.tickers.last.last_price} USDT, 时间: #{Time.now.strftime('%F %T')}"
    User.wechat_group_notice(title,desp)
  end

  def full_chain_notice(block)
    title = "#{block.block} 加仓通知"
    content = "#{block.block}位于 MA 上涨点，价格:#{block.tickers.last.last_price} USDT,
    买入价格：#{block.buy_business.first.price},
    持有数量：#{block.buy_business.map {|x| x.amount }.sum},
    本金数额：#{block.buy_business.map {|x| x.total }.sum}"
    User.wechat_notice(title,content)
  end

  def empty_chain_notice(block)
    title = "#{block.block} 空仓通知"
    content = "#{block.block}位于 MA 下跌点，价格:#{block.tickers.last.last_price} USDT,
    买入价格：#{block.buy_business.first.price},
    持有数量：#{block.buy_business.map {|x| x.amount }.sum},
    本金数额：#{block.buy_business.map {|x| x.total }.sum}"
    User.wechat_notice(title,content)
  end

end