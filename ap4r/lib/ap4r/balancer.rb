# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require "socket"
require "monitor"

module Ap4r

  class Balancer

    def initialize(config, logger)
      if config
        alias :get :get_with_config
        @monitors = config["targets"].to_a.map { |target|
          host, port = if target.kind_of? String
                         target.split(":")
                       else
                         [target[:host], target[:port]]
                       end
          TargetMonitor.new host, port, self, logger
        }
      else
        alias :get :get_without_config
      end

      @config = config
      @logger = logger
      @locker = Monitor.new
      @cond   = @locker.new_cond
    end

    def start
      return unless @config
      @logger.info { "start balancer with config\n#{@config.to_yaml}" }
      @monitors.each { |m| m.start }
    end

    def stop
      @logger.info { "stop balancer" }
      return unless @config
      @monitors.each { |m| m.stop }
    end

    def get_with_config
      target = @locker.synchronize { 
        actives = []
        @cond.wait_while {
          actives = @monitors.select{ |m| m.status == :active }
          !Thread.current[:dying] && actives.empty?
        }
        return nil if Thread.current[:dying]
        active = actives.sort_by{ rand }.first
        active.status = :processing
        active
      }
      begin
        yield target.host, target.port
      ensure 
        target.status = :active if target.status == :processing
      end
    end

    def get_without_config
      yield nil, nil
      nil
    end

    def on_target_state_changed
      @locker.synchronize {
        @cond.signal
      }
    end


    class TargetMonitor

      attr_reader :host, :port

      def initialize host, port, balancer, logger
        @host     = host
        @port     = port
        @balancer = balancer
        @logger   = logger
        @status   = :inactive
        @locker   = Monitor.new
      end

      def start
        @thread = Thread.fork{ monitor_loop }
        @logger.info { "monitor started. host: #{@host}, port:#{@port}" }
      end

      def stop
        @thread[:dying] = true
        @thread.wakeup rescue nil
        @thread.join
        @logger.info { "monitor stopped. host: #{@host}, port:#{@port}" }
      end

      def status
        @locker.synchronize {
          @status
        }
      end

      def status= value
        @locker.synchronize {
          @status = value
          @balancer.on_target_state_changed
        }
      end

      private

      def monitor_loop
        until Thread.current[:dying]
          ret = ping
          if ret
            self.status = :active if self.status == :inactive
          else
            self.status = :inactive
          end
          sleep 10
        end
      end

      def ping
        TCPSocket.open(@host, @port) { |s| true } rescue false
      end

    end
  end
end

