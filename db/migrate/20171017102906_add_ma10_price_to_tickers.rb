class AddMa10PriceToTickers < ActiveRecord::Migration
  def change
    add_column :tickers, :ma10_price, :float
    rename_column :tickers, :ma_price, :ma5_price
  end
end
