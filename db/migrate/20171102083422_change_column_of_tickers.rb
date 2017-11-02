class ChangeColumnOfTickers < ActiveRecord::Migration
  def change
    remove_column :tickers, :buy_price
    remove_column :tickers, :sell_price
    add_column :tickers, :volume, :float
  end
end
