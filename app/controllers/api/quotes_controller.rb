class Api::QuotesController < ApplicationController
  #每30分钟获取一直价格，生成历史行情
  def hit_tickers
    Chain.all.each do |item|
      item.generate_ticker rescue nil
      extremum_report(item)
    end
    render json:{code:200}
  end

  #每3分钟获取一次最新价格，与当前持有的货币成本价比较
  def hit_markets
    Chain.all.each do |item|
      market = item.market
      quote_analysis(item,market) if item.buy_price.to_i > 0
    end
    render json:{code:200}
  end

  #每天清空一次历史交易记录
  def hit_clear_business_orders
    Order.where(deal:1,repurchase:true).destroy_all
    Order.where(deal:0).destroy_all
  end

private

  def extremum_report(block)
    quotes = block.tickers.last(48)
    td_quotes = quotes.map {|x| x.last_price}
    if td_quotes.max == td_quotes[-1]
      chain_up_notice(block)
      up_sms_notice(block) if work_time
    elsif td_quotes.min == td_quotes[-1]
      chain_down_notice(block)
      down_sms_notice(block) if work_time
      buy_down_chain(block,td_quotes[-1]) if block.point && block.point.state && !work_time
    end
  end

  def amplitude(old_price,new_price)
    return ((new_price - old_price) / old_price * 100).to_i
  end

  def quote_analysis(block,market)
    high_price = market.first['High']
    low_price = market.first['Low']
    bid_price = market.first['Bid']
    ask_price = market.first['Ask']
    buy_price = block.buy_price
    if work_time
      if bid_price < buy_price * 0.95
        fall_price_notice(block,bid_price,buy_price)
      elsif bid_price > buy_price * 1.05
        high_price_notice(block,bid_price,buy_price)
      end
    end
    if bid_price > high_price * 0.99
      sell_market(block,bid_price)
    end
    if bid_price > buy_price * 1.1 && !work_time
      sell_market(block,bid_price)
    end
  end

  def sell_market(block,last_price)
    buy = block.buy_business.first
    balance = block.balance
    if buy && balance > 0 && last_price > buy.price * 1.0731
      amount = balance > buy.amount ? buy.amount : balance
      sell_chain(block,amount,last_price)
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

  def buy_down_chain(block,last_price)
    point = block.point
    avl_money = block.money
    buy_money = point.low_price
    had_buy = block.low_buy_business.count
    if had_buy == 0 && avl_money > 1
      money = avl_money * 0.9975 > buy_money ? buy_money : avl_money * 0.9975
      amount = (money / last_price).to_d.round(4,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
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

  def up_sms_notice(block)
    content = "#{block.block} 最高价值，价格: #{block.tickers.last.last_price} USDT, 时间: #{Time.now.strftime('%F %H:%M')}"
    User.sms_notice(content)
  end

  def down_sms_notice(block)
    content = "#{block.block} 最低价值，价格: #{block.tickers.last.last_price} USDT, 时间: #{Time.now.strftime('%F %H:%M')}"
    User.sms_notice(content)
  end

  def chain_up_notice(block)
    title = "#{block.block} 价格上涨"
    desp = "价格: #{block.tickers.last.last_price} USDT, 时间: #{Time.now.strftime('%F %H:%M')}"
    User.wechat_group_notice(title,desp)
  end

  def chain_down_notice(block)
    title = "#{block.block} 价格下跌"
    desp = "价格: #{block.tickers.last.last_price} USDT, 时间: #{Time.now.strftime('%F %H:%M')}"
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

  def fall_price_notice(block,bid_price,buy_price)
    title = "#{block.block} 低于成本价"
    content = "当前卖价：#{bid_price},购买成本：#{buy_price},时间：#{Time.now.strftime('%H:%M:%S')}"
    User.wechat_notice(title,content)
  end

  def high_price_notice(block,bid_price,buy_price)
    title = "#{block.block} 最大收益价"
    content = "当前卖价：#{bid_price},购买成本：#{buy_price},时间：#{Time.now.strftime('%H:%M:%S')}"
    User.wechat_notice(title,content)
  end
end