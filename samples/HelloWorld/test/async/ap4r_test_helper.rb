# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../../config/environment")

require 'erb'
require 'yaml'
require 'reliable-msg'
require 'ap4r'

class Ap4rTestHelper

  def initialize(config_file = RAILS_ROOT + "/config/ap4r.yml")
    raise "please create config/ap4r.yml to configure ap4r service." unless File.exist?(config_file)

    config = {}
    File.open(config_file, "r") do |input|
      YAML.load_documents(ERB.new(input.read).result) do |doc|
        config.merge! doc
      end
    end
    @test_config = config["test"]
    @root_dir = @test_config["root_dir"]
    @config_file = @test_config["config_file"]
    @test_server_config = ReliableMsg::Config.new(File.join(@root_dir, @config_file))
    raise "config file #{@test_server_config.path} NOT exist!" unless @test_server_config.exist?

    @test_server_config.load_no_create
    @qm = nil
  end

  def qm
    @qm ||= DRbObject.new_with_uri("druby://localhost:#{@test_server_config.drb["port"]}")
  end

  # Starts ap4r service.
  def start_ap4r_service(wait_until_started = true)
    command = "ruby #{@test_config["start_ruby_args"]} #{@root_dir}/script/mongrel_ap4r " +
      "start -d -c #{@root_dir} -A #{@config_file}"
    message = "Starting Mongrel(AP4R)"
    execute_command(command, message, false)
    if wait_until_started
      print "and waiting..."
      wait_until_alive
    end
    puts "Done."
  end

  # Stops ap4r service.
  def stop_ap4r_service
    command = "ruby #{@test_config["stop_ruby_args"]} #{@root_dir}/script/mongrel_ap4r " +
      "stop -c #{@root_dir}"
    message = "Terminating Mongrel(AP4R)"
    execute_command(command, message, false)
    @qm = nil
  end

  # Starts rails service.
  # Invokes mongrel_rails, so mongrel_rails should be installed.
  def start_rails_service
    # TODO: Can use script/server? It's more general. 2007/05/31 by shino
    command = "mongrel_rails start -d --environment test"
    message = "Starting Mongrel(Rails)"
    execute_command(command, message)
  end

  # Stops rails service.
  def stop_rails_service
    command = "mongrel_rails stop"
    message = "Terminating Mongrel(Rails)"
    execute_command(command, message, false)
  end

  # Starts rails service and ap4r service.
  # After block execution, stops both.
  def with_services
    begin
      start_rails_service
      begin
        start_ap4r_service
        yield
      ensure
        stop_ap4r_service
      end
    ensure
      stop_rails_service
    end
  end

  def start_dispatchers
    qm.dispatchers.start
  end

  def stop_dispatchers
    qm.dispatchers.stop
  end

  def clear(*queues)
    raise "not yet implemented"
    queues.each do |queue|
      q = ReliableMsg::Queue.new(queue)
      loop do
        break unless q.get
      end
    end
  end

  def wait_for_saf_forward
    50.times do
      count = ::Ap4r::StoredMessage.count(:conditions => {:status => ::Ap4r::StoredMessage::STATUS_STORED})
      break if count == 0
      sleep 0.2
    end
  end

  def wait_all_done
    50.times do
      break if flag = qm.no_active_message?
      sleep 0.2
    end
  end

  def dlq
    qm.list :queue => "$dlq"
  end

  private
  def execute_command(command, message, with_done_message = true)
    print "#{message} with command: #{command}..."
    system(command)
    puts "Done." if with_done_message
  end

  def wait_until_alive(message = nil)
    50.times do
      print message if message
      begin
        break if qm.alive?
      rescue => e
        # ignore
      end
      sleep 0.2
    end
  end

end


ap4r_test_helper = Ap4rTestHelper.new
ap4r_test_helper.start_rails_service
at_exit { ap4r_test_helper.stop_rails_service }

ap4r_test_helper.start_ap4r_service
at_exit { ap4r_test_helper.stop_ap4r_service }

puts
at_exit { puts }

# Test::Unit also use at_exit hook, so load at the end
require "#{File.dirname(__FILE__)}/../test_helper"

class Test::Unit::TestCase
  cattr_accessor :ap4r_helper

  def ap4r_helper
    @@ap4r_helper
  end

  def with_services(&block)
    ap4r_helper.with_services(&block)
  end
end

Test::Unit::TestCase.ap4r_helper = ap4r_test_helper
