class Api::QuotesController < ApplicationController
  #每30分钟获取一直价格，生成历史行情
  def hit_tickers
    Chain.all.each do |item|
      item.generate_ticker rescue nil
      extremum_report(item) rescue nil
    end
    render json:{code:200}
  end
  #每10分钟获取一次最新价格，根据价格涨幅做买卖通知
  def hit_markets
    Chain.all.each do |item|
      if item.point && item.point.state
        quote_macd_analysis(item)
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

  def quote_macd_analysis(block)
    market = block.market
    recent = block.tickers.last(10)
    macd_diff_last = recent.map {|x| x.macd_diff }
    diff_dea_last = recent.map {|x| x.macd_diff - macd_dea }
    if macd_diff_last.min > 0 && macd_diff_last[-1] == macd_diff_last.max
      sell_a_analysis(block,market)
    elsif macd_diff_last.min > 0 && macd_diff_last[-2] == macd_diff_last.max
      sell_b_analysis(block,market)
    elsif macd_diff_last.min > 0 && diff_dea_last[-1] < 0  && diff_dea_last[-2] > 0
      sell_c_analysis(block,market)
    elsif diff_dea_last[-1] < 0  && diff_dea_last[-2] > 0
      sell_c_analysis(block,market)
    elsif macd_diff_last.min > 0 && macd_diff_last[-2] == macd_diff_last.max
      buy_a_analysis(block,market)
    elsif macd_diff_last.max < 0 && diff_dea_last[-1] > 0 && diff_dea_last[-2] < 0
      buy_a_analysis(block,market)
    elsif macd_diff_last.max < 0 && macd_diff_last[-2] == macd_diff_last.min
      buy_a_analysis(block,market)
    elsif diff_dea_last[-1] > 0 && diff_dea_last[-2] < 0
      buy_a_analysis(block,market)
    end
  end

  def sell_a_analysis(block,market)
    last_price = market.first['Bid']
    balance = block.balance
    if balance > 0 && last_price > block.greater_income
      if  block.high_nearby(last_price)
        sell_chain(block,balance * 0.15,last_price)
      elsif  last_price > block.high
        sell_chain(block,balance * 0.3,last_price)
      else
        sell_chain(block,balance * 0.1,last_price)
      end
    end  
  end

  def sell_b_analysis(block,market)
    last_price = market.first['Bid']
    balance = block.balance
    if balance > 0 && last_price > block.greater_income
      if  block.high_nearby(last_price)
        sell_chain(block,balance * 0.2,last_price)
      else
        sell_chain(block,balance * 0.1,last_price)
      end
    end
  end

  def sell_c_analysis(block,market)
    last_price = market.first['Bid']
    balance = block.balance
    if balance > 0 && last_price > block.greater_income
        sell_chain(block,balance,last_price)
    end
  end

  def sell_d_analysis(block,market)
    last_price = market.first['Bid']
    balance = block.balance
    if balance > 0 && last_price > block.greater_income
        sell_chain(block,balance * 0.1,last_price)
    end
  end

  def buy_a_analysis(block,market)
    last_price = market.first['Ask']
    money = block.batch_money
    if money > 0
      amount = (money/last_price).to_d.round(4,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
    end
  end

  def buy_analysis(block,market)
    last_price = market.first['Ask']
    low_price = market.first['Low']
    money = block.batch_money
    if last_price < block.low && last_price > low_price && money > 0
      amount = (money/last_price).to_d.round(4,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
    elsif block.low_nearby(last_price)
      amount = (money/last_price).to_d.round(4,:truncate).to_f
      buy_chain(block,point.unit,last_price) if amount > 0
    elsif block.kling_down_up_point? && last_price < block.tickers.last.last_price
      amount = (money/last_price).to_d.round(4,:truncate).to_f
      buy_chain(block,amount,last_price) if amount > 0
    end
  end

  def sell_analysis(block,market)
    last_price = market.first['Bid']
    high_price = market.first['High']
    amount = block.point.unit
    balance = block.balance
    if last_price > block.greater_income && balance > 0
      if last_price > block.high && last_price < high_price
        batch_part_sell(block,amount,balance,last_price,0.3)
      elsif block.high_nearby(last_price)
        batch_part_sell(block,amount,balance,last_price,0.25)
      elsif block.kling_up_down_point? && last_price > block.tickers.last.last_price
        batch_part_sell(block,amount,balance,last_price,0.2)
      end
    elsif last_price < block.last_buy_price * 0.9382 && balance > 0
      sell_chain(block,balance,last_price)
      block.close_merch
      User.sms_notice("#{block.block},止损点,价值:#{td_quotes[-1]} #{block.currency},时间:#{Time.now.strftime('%H:%M')}")
    end
  end

  def batch_part_sell(block,amount,balance,price,percent)
    sell_chain(block,(balance * percent).round(4),price) if (balance * percent).round(4) > amount
    sell_chain(block,amount,price) if (balance * percent).round(4) < amount && amount < balance
    sell_chain(block,balance,price) if balance < amount
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
    td_quotes = block.tickers.last(48).map {|x| x.last_price}
    if td_quotes.max == td_quotes[-1]
      User.sms_batch("#{block.block},行情最高点,价值:#{td_quotes[-1]} #{block.currency},时间:#{Time.now.strftime('%H:%M')}")
    elsif td_quotes.min == td_quotes[-1]
      User.sms_batch("#{block.block},行情最低点,价值:#{td_quotes[-1]} #{block.currency},时间:#{Time.now.strftime('%H:%M')}")
    end
  end

end