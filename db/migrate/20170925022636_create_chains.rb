class CreateChains < ActiveRecord::Migration
  def change
    create_table :chains do |t|
      t.string  :block
      t.string  :currency
      t.string  :label
      t.timestamps null: false
    end
  end
end
