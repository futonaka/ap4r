namespace :test do

#  task :asyncs do
#    setup - run - teardown comes here.
#    Names should be considered further.
#  end

  namespace :asyncs do

    desc "Start Rails and AP4R servers to test:asyncs:exec"
    task :arrange => :require_dependencies do |t|
      ap4r_handler = Ap4r::ServiceHandler.new
      ap4r_handler.start_rails_service
      ap4r_handler.start_ap4r_service
    end

    desc "Start Rails and AP4R servers to test:asyncs:exec"
    task :cleanup => :require_dependencies do |t|
      ap4r_handler = Ap4r::ServiceHandler.new
      ap4r_handler.stop_ap4r_service
      ap4r_handler.stop_rails_service
    end

    Rake::TestTask.new(:run => "db:test:prepare") do |t|
      t.libs << "test"
      t.pattern = 'test/async/**/*_test.rb'
      t.verbose = true
    end
    Rake::Task['test:asyncs:run'].comment = "Run the unit tests in test/async"

    # service_handler.rb needs to require the following libraries.
    # If reliable-msg's rails adapter is loaded before rails initialization,
    # it may cause to uninitialization error because the adapter requires ActionController.
    # So, the load of the following libraries is delayed with rake task.
    task :require_dependencies do
      require File.expand_path(File.dirname(__FILE__) + "/../lib/ap4r/service_handler.rb")
    end
  end
end

 namespace :db do
  namespace :ap4r do
    desc "Create SAF migration file."
    task :create_saf => :environment do |t|

      require 'rails_generator'
      require 'rails_generator/scripts/generate'

      args = %w(migration create_stored_messages)
      Rails::Generator::Scripts::Generate.new.run(args)

      migration_directory = "#{RAILS_ROOT}/db/migrate"
      migration_name      = "create_stored_messages"
      migration_file_name = Dir.glob("#{migration_directory}/[0-9]*_*.rb").grep(/[0-9]+_#{migration_file_name}.rb$/).first

      File.open(migration_file_name, "w") do |f|
        f.write <<EOS
class CreateStoredMessages < ActiveRecord::Migration
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
EOS
      end
    end
  end
end


