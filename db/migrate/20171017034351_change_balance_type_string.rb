class ChangeBalanceTypeString < ActiveRecord::Migration
  def change
    change_column :balances, :balance, :string
    change_column :balances, :available, :string
    change_column :balances, :pending, :string
  end
end
