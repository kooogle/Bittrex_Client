class Api::QuotesController < ApplicationController
  #每15分钟获取一次格，生成历史行情
  def hit_tickers
    Chain.all.each do |item|
      item.generate_ticker rescue nil
    end
    Chain.all.each do |item|
      extremum_report(item) if item.point && item.point.state
    end
    render json:{code:200}
  end

  #每5分钟获取一次最新价格，与当前持有的货币成本价比较
  def hit_markets
    Chain.all.each do |item|
      market = item.market
      quote_analysis(item,market) if item.buy_price.to_i > 0
      high_business(item,market) if item.point && item.point.state
    end
    render json:{code:200}
  end

  #每天清空一次历史交易记录
  def hit_clear_business_orders
    Order.where(deal:1,repurchase:true).destroy_all
    Order.where(deal:0).destroy_all
    render json:{code:200}
  end

  def hit_clear_open_orders
    Chain.all.each do |block|
      clear_open_orders(block) if block.buy_business.count > 0
    end
    Order.where(state:false).destroy_all #清空交易失败的订单
    render json:{code:200}
  end

private

  def extremum_report(block)
    quotes = block.tickers.last(96)
    td_quotes = quotes.map {|x| x.last_price}
    if td_quotes.max == td_quotes[-1]
      # chain_up_notice(block)
      up_sms_notice(block) if work_time
    elsif td_quotes.min == td_quotes[-1]
      # chain_down_notice(block)
      down_sms_notice(block) if work_time
    end
  end

  def macd_business(block)
    quotes = block.tickers.last(2)
    market = block.market
    bid_price = market['Bid']
    macd_diff = quotes.map {|x| x.macd_diff }
    if macd_diff[-1] > 0 && macd_diff[-2] < 0
      buy_down_chain(block,bid_price)
    elsif macd_diff[-1] < 0 && macd_diff[-2] > 0
      sell_down_chain(block,bid_price)
    end
  end

  def quote_analysis(block,market)
    high_price = market['High']
    low_price = market['Low']
    bid_price = market['Bid']
    buy_price = block.buy_price
    quotes_3 = block.tickers.last(3).map {|x| x.last_price}
    if bid_price < buy_price * 0.95
      fall_price_notice(block,bid_price,buy_price) if work_time
    elsif bid_price > buy_price * 1.05
      high_price_notice(block,bid_price,buy_price) if work_time
    end
    if bid_price > high_price * 0.99
      batch_sell_profit(block,bid_price,1.0618)
    end
    if quotes_3 == quotes_3.uniq.sort {|x,y| y<=>x }
      if bid_price < buy_price * 0.975
        all_out(block,bid_price)
      end
    end
  end

  def high_business(block,market)
    quotes = block.tickers.last(7)
    bid_price = market['Bid']
    macd_diff = quotes.map { |x| x.macd_diff }
    macd_dea_diff = quotes.map { |x| x.macd_diff - x.macd_dea }
    ma_diff = quotes.map { |x| x.ma5_price - x.ma10_price }
    stock = quotes.map { |x| x.last_price }
    buy = block.high_buy_business.order(price: :asc).first
    if macd_diff[-1] > 0
      batch_sell_profit(block,bid_price,1.05)
      if bid_price < stock[-1] * 1.01
        if ma_diff[-2] == ma_diff.min
          high_buy_market(block,bid_price)
        elsif ma_diff[-1] > 0 && ma_diff[-2] < 0
          high_buy_market(block,bid_price)
        end
      end
      h6_quotes = block.tickers.last(12).map { |x| x.last_price }
      if h6_quotes[-1] == h6_quotes.min && bid_price < stock[-1] * 1.005 && macd_dea_diff[-1] > 0
        high_buy_market(block,bid_price)
      end
      if buy && bid_price > buy.price * 1.01 && ma_diff[-2] == ma_diff.max
        high_sell_chain(block,buy.amount,bid_price)
        batch_sell_profit(block,bid_price,1.025)
      end
    end
    if macd_diff[-1] < 0
      batch_sell_profit(block,bid_price,1.025)
      if ma_diff[-2] == ma_diff.min && ma_diff[-2] < 0
        if bid_price < stock[-1] * 1.005
          high_buy_market(block,bid_price)
        end
      end
      if buy && bid_price > buy.price * 1.015 && ma_diff[-2] == ma_diff.max
        high_sell_chain(block,buy.amount,bid_price)
        batch_sell_profit(block,last_price,1.02)
      end
    end
  end

  def high_buy_market(block,last_price)
    buy = block.high_buy_business
    point = block.point
    balance = block.money
    avl_money = point.high_price
    tol_money = point.high_value
    had_money = buy.map {|x| x.total }.sum
    if had_money < tol_money && balance * 0.9975 > avl_money
      amount = (avl_money / last_price).to_d.round(4,:truncate).to_f
      high_buy_chain(block,amount,last_price)
    end
  end

  def high_sell_market(block,last_price)
    buy = block.high_buy_business.order(price: :asc).first
    balance = block.balance
    if buy && balance > 0 && last_price > buy.price * 1.02
      amount = balance > buy.amount ? buy.amount : balance
      high_sell_chain(block,amount,last_price)
    end
    if buy && last_price > buy.price * 1.025
        batch_sell_profit(block,last_price,1.025)
    end
  end

  def amplitude(old_price,new_price)
    return ((new_price - old_price) / old_price.to_f * 100).to_i
  end

  def sell_market(block,last_price)
    buy = block.low_buy_business.first
    balance = block.balance
    if buy && balance > 0 && last_price > buy.price * 1.1
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
    if had_buy == 0 && avl_money > 1 && buy_money > 1
      money = avl_money * 0.9975 > buy_money ? buy_money : avl_money * 0.9975
      amount = (money / last_price).to_d.round(4,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
    end
  end

  def sell_down_chain(block,last_price)
    buy = block.low_buy_business.first
    balance = block.balance
    if buy && balance > 0 && last_price > buy.price * 1.01
      amount = balance > buy.amount ? buy.amount : balance
      sell_chain(block,amount,last_price)
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
    content = "#{block.block} 最高价值，价格: #{block.tickers.last.last_price} #{block.currency}, 价值: #{block.to_usdt} USDT"
    User.sms_notice(content)
  end

  def down_sms_notice(block)
    content = "#{block.block} 最低价值，价格: #{block.tickers.last.last_price} #{block.currency}, 价值: #{block.to_usdt} USDT"
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

  def all_out(block,price)
    begin
      amount = block.balance
      sell_chain(block,amount,price)
      block.business.where(deal:1).destroy_all
    rescue
      nil
    end
  end

  def batch_sell_profit(block,price,rate)
    orders = block.high_buy_business.order(price: :asc)
    if orders.count > 0
      orders.each do |item|
        if price > item.price * rate
          high_sell_chain(block,item.amount,price)
        end
      end
    end
  end

  def clear_open_orders(block)
    market = "#{block.currency}-#{block.block}"
    open_orders = Order.pending(market)
    open_orders['result'].each do |order|
      cancel_order(order)
    end
  end

  def cancel_order(order)
    if uuid = order['OrderUuid']
      Order.cancel(uuid)
      Order.find_by_result(uuid).destroy rescue nil
    end
  end

end