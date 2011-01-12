# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

begin require 'rubygems'; rescue LoadError; end

require 'yaml'
require 'thread'
require 'active_support'
require 'reliable-msg'

module Ap4r

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
      @group.list.each{|d| d.join }
    end

    private
    def recoverer_loop group, recoverer
      group.add Thread.current
      @logger.info { "starting a recoverer (index #{index})" }
      every = recoverer["every"].to_f
      count = recoverer["count"].to_i
      select_cond = eval(recoverer["selector"])

      selector = ReliableMsg::Queue.selector &select_cond

      until Thread.current[:dying]
        begin
          sleep every
          dlq = ReliableMsg::Queue.new "$dlq"

          count.times {
            message_exist = dlq.get(selector) { |m|
              dlq.put m.object, m.headers
            }
            break unless message_exist
          }

        rescue Exception => ex
          @logger.warn "error in recover #{ex}\n#{ex.backtrace.join("\n\t")}\n"
        end
      end
      @logger.info { "ends a recoverer" }
    end

  end
end
