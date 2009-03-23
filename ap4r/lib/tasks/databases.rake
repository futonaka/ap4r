require 'rubygems'
require 'erb'
require 'find'
require 'active_record'
require File.join(File.dirname(__FILE__), '/../ap4r/version')

namespace :qdb do
  desc "Make queue and topic tables through scripts in lib/ap4r/db/migrate."
  task :migrate do

    # Todo: configurable file name, 2007/10/01 kiwamu
    ap4r_config_file = "config/queues_ar.cfg"
    ap4r_config = YAML::load(ERB.new(IO.read(ap4r_config_file)).result)
    database_config = ap4r_config["store"]
    if "activerecord" == database_config["type"].downcase
      database_config["adapter"] = database_config["adapter"].downcase
    else
      # Todo
    end
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.establish_connection(database_config)

    ActiveRecord::Migrator.migrate("lib/ap4r/db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end
end

