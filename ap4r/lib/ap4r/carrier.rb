# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

begin require 'rubygems'; rescue LoadError; end

require 'yaml'
require 'thread'
require 'pp'
require 'active_support'
require 'reliable-msg'

module Ap4r

  # This class aims to balance loads of several reliable-msg servers.
  # Only P2P channells (queues) are considered so far.
  # Now reliable-msg can not be accessed from remote (means "not localhost").
  # Alpha status now.
  #--
  # TODO: refactoring with dispatcher.rb, around thread group, etc. 2007/05/09 by shino
  class Carriers

    def initialize(queue_manager, config, logger, dispatchers)
      @qm = queue_manager
      @config = config
      @logger = logger
      @group = ThreadGroup.new
      @dispatchers = dispatchers
    end

    def start
      return unless @config
      @logger.info{ "ready to start carrires with config #{@config.to_yaml}" }
      @config.each { |remote|
        remote["threads"].times { |index|
          Thread.fork(@group, remote, index){|group, remote, index|
            carrier_loop(group, remote, index)
          }
        }
      }
      @logger.info{"queue manager has forked all carriers"}
    end

    def stop
      @logger.info{"stop_carriers #{@group}"}
      return unless @group
      @group.list.each{|d| d[:dying] = true}
      @group.list.each{|d| d.join }
    end

    private
    def carrier_loop(group, remote, index)
      # TODO: refactor structure, 2006/10/06 shino
      group.add Thread.current
      @logger.info{ "starting a carrier (index #{index}) for the queue manager #{remote['source_uri']}" }
      uri = remote['source_uri']
      until Thread.current[:dying]
        begin
          sleep 0.1
          # TODO check :dying flag here and break, 2006/09/01 shino
          # TODO cache DRbObject if necessary, 2006/09/01 shino
          remote_qm = DRb::DRbObject.new_with_uri(uri)
          queue_name = remote_qm.stale_queue dispatch_targets
          next unless queue_name

          @logger.debug{ "stale queue name : #{queue_name}" }
          q = ReliableMsg::Queue.new queue_name, :drb_uri => uri
          q.get { |m|
            unless m
              @logger.debug{ "carrier strikes at the air (T_T)" }
              next
            end
            # @logger.debug{ "carrier gets a message\n#{m.to_yaml}" }

            # TODO: decide the better one, and delete another, 2006/09/01 shino
            # TODO: or switchable implementation in versions, 2006/10/16 shino

            # version 1: use thread fork so queue manager use a different tx
            # TODO probably should have a thread as an instance variable or in a thread local, 2006/09/01 shino
            # Thread.fork(m) {|m|
            #   local_queue = ReliableMsg::Queue.new queue_name
            #   local_queue.put m.object
            # }.join

            #version 2: store tx and set nil, and resotre tx after putting a message
            begin
              tx = Thread.current[ReliableMsg::Client::THREAD_CURRENT_TX]
              Thread.current[ReliableMsg::Client::THREAD_CURRENT_TX] = nil
              # @logger.debug{ "before tx: #{tx}" }
              ReliableMsg::Queue.new(queue_name).put(m.object)
            ensure
              Thread.current[ReliableMsg::Client::THREAD_CURRENT_TX] = tx
              # @logger.debug{ "after tx: #{Thread.current[ReliableMsg::Client::THREAD_CURRENT_TX]}" }
            end
          }
        rescue Exception => ex
          @logger.warn "error in remote-get/local-put #{ex}\n#{ex.backtrace.join("\n\t")}\n"
        end
      end
      @logger.info{"ends a carrier (index #{index}) for the queue manager #{remote['uri']}"}
    end

    def dispatch_targets
      @dispatchers.targets
    end

  end
end
