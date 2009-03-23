# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'active_support'
require 'yaml'
require 'thread'
require 'pp'
require 'erb'
require 'uuid'
require 'reliable-msg'

require 'ap4r/message_store_ext'
require 'ap4r/multi_queue'
require 'ap4r/retention_history'
require 'ap4r/dispatcher'
require 'ap4r/carrier'

module ReliableMsg #:nodoc:

  # = Dynamic configuration with ERb
  #
  # Some times you would like to inject dynamic values into your configuration file.
  # In these cases, you can mix ERb in with your YAML to code some logic, like:
  #
  # <% acl = [] %>
  # <% for i in 1..100 %>
  # <% acl << "192.168.0.#{i}" %>
  # <% end %>
  # acl: <%= acl.map{|ip| "allow #{ip}"}.join(' ')
  #
  class Config

    alias :load_no_create_original :load_no_create
    alias :load_or_create_original :load_or_create

    #--
    # TODO: should enhance YAML.load_documents instead of this method?, 2007/5/7 kato-k
    def load_no_create
      if File.exist?(@file)
        @config= {}
        File.open @file, "r" do |input|
          YAML.load_documents(erb_render(input.read)) do |doc|
            @config.merge! doc
          end
        end
        true
      end
    end

    #--
    # TODO: should enhance YAML.load_documents instead of this method?, 2007/5/7 kato-k
    def load_or_create
      if File.exist?(@file)
        @config= {}
        File.open @file, "r" do |input|
          YAML.load_documents(erb_render(input.read)) do |doc|
            @config.merge! doc
          end
        end
        @logger.info format(INFO_LOADED_CONFIG, @file)
      else
        @config = {
          "store" => DEFAULT_STORE,
          "drb" => DEFAULT_DRB
        }
        save
        @logger.info format(INFO_CREATED_CONFIG, @file)
      end
    end

    private
    def erb_render(configuration_content)
      ::ERB.new(configuration_content).result
    end
  end

  class QueueManager

    # Gets a queue name which has the most stale message.
    # +multi_queue+ specifies the target queue names to search.
    def stale_queue multi_queue
      @store.stale_queue multi_queue
    end

    alias :start_original :start
    alias :stop_original :stop
    alias :initialize_original :initialize

    # Hooks original initialize method to add lifecyle listeners.
    #--
    # TODO: Make dispatchers and carriers lifecyle listeners, 2006/09/01 shino
    def initialize options = nil #:notnew:
      initialize_original options
      @global_lock ||= Mutex.new
      @lifecycle_listeners = []
      RetentionHistory.new(self, @logger, @config)
    end

    def add_lifecycle_listener listener, iv_name, attr_mode = 'reader'
      @lifecycle_listeners << listener
      instance_variable_set "@#{iv_name}".to_sym, listener
      self.class.class_eval("attr_#{attr_mode} :#{iv_name}")
    end

    # Starts reliable-msg server and something around it.
    #
    # Order is:
    # 1. Original reliable-msg server (message store and druby).
    # 2. Dispatchers
    # 3. Carriors (if exists)
    # These are Reversed in +stop+.
    def start
      begin
        @global_lock.synchronize do
          return if @@active == self
          start_original

          @dispatchers = ::Ap4r::Dispatchers.new(self, @config.dispatchers, @logger)
          @dispatchers.start

          @carriors = ::Ap4r::Carriers.new(self, @config.carriers, @logger, @dispatchers)
          @carriors.start

          @lifecycle_listeners.each {|l| l.start }
        end
      rescue Exception => err
        @logger.warn{"Error in starting queue-manager #{err}"}
        @logger.warn{err.backtrace.join("\n")}
      end
    end

    # Stops reliable-msg server and something around it.
    # See +start+ also.
    def stop
      @global_lock.synchronize do
        return unless @@active == self
        @lifecycle_listeners.each {|l| l.stop }
        @carriors.stop
        @dispatchers.stop
        stop_original
      end
    end


  end
end
