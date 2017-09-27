class CreateBalances < ActiveRecord::Migration
  def change
    create_table :balances do |t|
      t.string   :block
      t.float    :balance
      t.float    :available
      t.float    :pending
      t.string   :address
      t.timestamps null: false
    end
  end
end
