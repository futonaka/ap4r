class CreateOrders < ActiveRecord::Migration
  def self.up
    create_table :orders do |t|
      t.column :item, :string
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :orders
  end
end
