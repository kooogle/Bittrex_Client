class CreatePoints < ActiveRecord::Migration
  def change
    create_table :points do |t|
      t.integer   :chain_id
      t.integer   :weights
      t.float     :total_amount
      t.float     :total_value
      t.float     :unit
      t.boolean   :state
      t.timestamps null: false
    end
  end
end
