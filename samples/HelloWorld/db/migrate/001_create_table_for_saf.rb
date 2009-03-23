# Author:: Kiwamu Kato
# Copyright:: Copyright (c) 2006 Future System Consulting Corp.
# Licence:: MIT Licence

class CreateTableForSaf < ActiveRecord::Migration
  def self.up
    create_table :stored_messages do |t|
      t.column :duplication_check_id, :string, :null => false
      t.column :queue, :string, :null => false
      t.column :headers, :binary, :null => false
      t.column :object, :binary, :null => false
      t.column :status, :integer, :null => false
      t.column :created_at, :datetime, :null => false
      t.column :updated_at, :datetime, :null => false
    end
  end

  def self.down
    drop_table :stored_messages
  end
end
