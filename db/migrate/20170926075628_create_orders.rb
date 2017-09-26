class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.integer   :chain_id
      t.integer   :deal
      t.float     :amount
      t.float     :price
      t.float     :total
      t.boolean   :state
      t.timestamps null: false
    end
  end
end
