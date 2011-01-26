# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

begin require 'rubygems'; rescue LoadError; end

require 'yaml'
require 'thread'
require 'active_support'
require 'reliable-msg'

module Ap4r

  # This class aims to recover DLQ messages.
  # You can set some values to change the behavior in config file.
  #
  # threads:    The count of recoverer threads.
  # every:      The time to repeat per it. 
  # count:      The count of messages recovered every time.
  # on_expired: The Processing for :max_deliveries times recovered messages.
  #   ex) configuration to put the message to DLQ again.
  #     <pre>
  #       on_expired: "Proc.new{ |m| dlq.put(m.object, m.headers)}"
  #     </pre>
  #
  class Recoverers

    def initialize(queue_manager, config, logger)
      @qm = queue_manager
      @config = config
      @logger = logger
      @group = ThreadGroup.new
    end

    def start
      return unless @config
      @logger.info{ "ready to start recoverer with config #{@config.to_yaml}" }
      @config.each { |recoverer|
        recoverer["threads"].times { |index|
          Thread.fork(@group, recoverer, index) { |group, recoverer, index|
            recoverer_loop(group, recoverer, index)
          }
        }
      }
      @logger.info{"queue manager has forked recoverer"}
    end

    def stop
      @logger.info{"stop_recoverer #{@group}"}
      return unless @group
      @group.list.each{|d| d[:dying] = true}
      @group.list.each{|d| d.wakeup rescue nil}
      @group.list.each{|d| d.join }
    end

    private
    def recoverer_loop group, recoverer, index
      group.add Thread.current
      @logger.info { "starting a recoverer (index #{index})" }
      every      = recoverer["every"].to_f
      count      = recoverer["count"].to_i
      on_expired = eval(recoverer["on_expired"].to_s) || Proc.new { |m| }

      until Thread.current[:dying]
        begin
          dlq = ReliableMsg::Queue.new "$dlq"

          ids = @qm.list(:queue => "$dlq")[0..(count - 1)].map { |headers|
            headers[:id]
          }

          ids.each { |id|
            dlq.get(:id => id) { |m|
              if m.headers[:max_deliveries] <= m.headers[:redelivery]
                on_expired.call(m)
                next
              end

              ReliableMsg::Queue.new(m.headers[:queue_name]).put(m.object, m.headers)
            }
          }

          sleep every

        rescue Exception => ex
          @logger.warn "error in recover #{ex}\n#{ex.backtrace.join("\n\t")}\n"
        end
      end

    rescue => ex
      @logger.error "error in recover #{ex}\n#{ex.backtrace.join("\n\t")}\n"

    ensure
      @logger.info { "ends a recoverer (index #{index})" }
    end

  end
end
